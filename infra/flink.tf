# Managed Service for Apache Flink 애플리케이션 리소스 정의 파일

locals {
  # flink 앱 경로. flink-silver.zip 파일은 스크립트에서 정의, flink 최종 산출물의 경로
  # ${path.module} => ~/infra (현재 디렉토리 위치)
  # -> infra 폴더 기준 한 단계 위(log_gen)로 올라간 뒤 flink/target/ 안의 zip 파일을 가리킴
  flink_artifact_path = "${path.module}/../flink/target/flink-silver.zip"

  # zip 내용에 MD5 해시를 계산하여 코드 변경 여부 식별 용도
  # -> zip 파일 내용이 바뀌면 해시값도 바뀌어서, terraform이 "코드가 변경됐다"고 인식하게 만드는 용도
  flink_artifact_hash = filemd5(local.flink_artifact_path)
}

# flink_app이란 flink-silver.zip이고, aws s3에 위치해야 함
# Managed Service for Apache Flink는 애플리케이션 코드를 S3에서 읽어와 실행하는 구조라
# 로컬에서 빌드한 zip 파일을 여기서 S3 버킷으로 업로드하는 리소스
resource "aws_s3_object" "flink_app" {
  bucket = aws_s3_bucket.data.id # 업로드할 대상 S3 버킷
  key    = "flink/applications/flink-silver-${local.flink_artifact_hash}.zip"
  # 파일명 뒤에 해시값을 붙여서, 코드가 바뀔 때마다 S3에 새로운 객체(새 key)로 올라가게 함
  # -> 이러면 애플리케이션 업데이트 시 새 zip을 가리키게 되어 재배포가 트리거됨

  source      = local.flink_artifact_path # 실제로 업로드할 로컬 파일 경로
  source_hash = local.flink_artifact_hash # 이 해시가 바뀌면 terraform이 재업로드를 수행

  depends_on = [
    aws_s3_bucket_public_access_block.data
    # 이 버킷의 퍼블릭 액세스 차단 설정이 먼저 적용된 뒤에 객체를 업로드하도록 순서를 보장
  ]
}

# flink 자체 내용
# 실제 Managed Service for Apache Flink 애플리케이션(스트림 처리 job) 리소스
resource "aws_kinesisanalyticsv2_application" "silver" {
  name                   = local.flink_application_name # Flink 애플리케이션 이름
  description            = "Raw Kinesis events to Silver Kinesis using PyFlink"
  runtime_environment    = var.flink_runtime_environment # 예: FLINK-1_20 (Flink 실행 버전)
  service_execution_role = aws_iam_role.flink.arn        # 이 애플리케이션이 assume할 IAM Role
  start_application      = var.flink_start_application   # apply 직후 자동으로 실행할지 여부

  application_configuration {
    application_snapshot_configuration {
      snapshots_enabled = false
      # 애플리케이션을 멈추거나 업데이트할 때 상태(state) 스냅샷을 저장할지 여부
      # false면 재시작/업데이트 때마다 상태 없이 처음부터 다시 시작함
    }

    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = aws_s3_bucket.data.arn      # 코드가 있는 S3 버킷
          file_key   = aws_s3_object.flink_app.key # 위에서 업로드한 zip의 정확한 key(경로)
        }
      }

      code_content_type = "ZIPFILE" # 코드가 zip 압축 형태로 제공됨을 명시
    }

    environment_properties {
      # 런타임에 Flink 코드(main.py 등)가 조회해서 쓰는 설정값들의 모음
      # 코드 안에서 get_property_group("그룹ID")로 이 값들을 읽어옴

      property_group {
        property_group_id = "InputStream0" # 입력(Bronze) 스트림 설정 그룹

        property_map = {
          "stream.arn"                 = aws_kinesis_stream.bronze.arn  # 읽어올 Kinesis 스트림 ARN
          "aws.region"                 = var.aws_region                 # 리전
          "flink.source.init.position" = var.flink_source_init_position # LATEST 또는 TRIM_HORIZON
        }
      }

      property_group {
        property_group_id = "OutputStream0" # 출력(Silver) 스트림 설정 그룹

        property_map = {
          "stream.arn" = aws_kinesis_stream.silver.arn # 결과를 써넣을 Kinesis 스트림 ARN
          "aws.region" = var.aws_region
        }
      }

      property_group {
        property_group_id = "kinesis.analytics.flink.run.options"
        # AWS가 예약해둔 특수 이름의 property group
        # PyFlink 애플리케이션의 진입점 파일들을 zip 안에서 찾을 수 있게 알려주는 용도

        property_map = {
          "python"  = "main.py"                      # 실행할 파이썬 메인 파일
          "jarfile" = "lib/pyflink-dependencies.jar" # 커넥터 등 Java 의존성이 담긴 JAR
          "pyFiles" = "transform.py"                 # 추가로 참조하는 파이썬 리소스 파일
        }
      }
    }

    flink_application_configuration {
      checkpoint_configuration {
        configuration_type = "DEFAULT"
        # Flink 자체의 체크포인트(런타임 중 장애 복구용) 설정
        # DEFAULT면 Flink 기본값(체크포인트 활성화, 약 60초 간격)을 그대로 사용
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = "INFO"        # 로그 상세도
        metrics_level      = "APPLICATION" # 메트릭 수집 단위(애플리케이션 전체 단위)
      }

      parallelism_configuration {
        configuration_type   = "CUSTOM"
        auto_scaling_enabled = true                          # 부하에 따라 자동으로 병렬도 조정
        parallelism          = var.flink_parallelism         # 초기 병렬 처리 개수
        parallelism_per_kpu  = var.flink_parallelism_per_kpu # KPU 1개당 할당할 병렬 태스크 수
      }
    }
  }

  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.flink.arn
    # 이 Flink 애플리케이션의 로그를 보낼 CloudWatch 로그 스트림 ARN
  }

  depends_on = [
    aws_iam_role_policy.flink, # IAM 정책이 role에 먼저 붙은 뒤에 애플리케이션 생성
    aws_s3_object.flink_app    # 코드가 S3에 먼저 업로드된 뒤에 애플리케이션 생성
  ]

  tags = {
    DataLayer = "silver" # 이 리소스가 속한 데이터 레이어 태그
    Processor = "flink"  # 이 리소스가 어떤 처리 엔진인지 태그
  }
}