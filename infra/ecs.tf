# 컨테이너의 실행환경 제공
# 1. 클러스터 생성
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name
}
# 2. Fargate에서 실행할 로그 생성기 컨테이너에 대한 실행시 명세서(률, 설정, ....)
resource "aws_ecs_task_definition" "generator" {
  # 관리단 => family, 소속그룹
  # de-ai-25-loggen-task:1 => de-ai-25-loggen-task:2 => ... 수정발생 => 넘버를 부여하여 새로 생성
  family = local.task_family

  # FARGATE 사용 : task가 어떻게 정의된 실행환경에서 사용한 것인지 지정 -> ec2 x, 
  requires_compatibilities = ["FARGATE"]

  # 네트워크 구성, task가 작동할때마다 a존 or b존에 매번 상이하게 할당
  network_mode = "awsvpc"

  # cpu 사용(자원)
  cpu    = tostring(var.task_cpu)
  memory = tostring(var.task_mem)

  # 권한 (ecs 테스크(기본), push, 로그기록)
  execution_role_arn = aws_iam_role.ecs_execution.arn

  # 서버리스 => 컴퓨팅 자원의 운영쳬게
  runtime_platform {
    operating_system_family = "LINUX"  # 컨테이너 실행 환경
    cpu_architecture        = "X86_64" # 아킥텍쳐
  }

  # 컨테이너 상세 정의서(명세서)
  container_definitions = jsonencode([
    {
      # 컨테이너 명  
      name = "log-generator"

      # 이미지명
      image = "${aws_ecr_repository.generator.repository_url}:${var.image_tag}"

      # 해당 컨테이너가 본 task의 필수 컨테이너다. 선언
      essential = true

      # 환경변수
      # 환경변수
      environment = [
        # 어떤 도메인의 로그를 생성할지 (예: 이커머스 도메인 이벤트 시뮬레이션)
        { name = "DOMAIN", value = "ecommerce" },

        # 로그 생성기가 몇 초 동안 실행될지 (300초 = 5분)
        { name = "DURATION_SECONDS", value = "300" },

        # 생성할 최대 이벤트(로그) 개수 상한. 0이면 무제한(DURATION_SECONDS로만 종료 제어하는 것으로 추정)
        { name = "MAX_EVENTS", value = "0" },

        # 초당 기준 요청/이벤트 발생률(Requests Per Second)
        { name = "BASE_RPS", value = "2.0" },

        # 시간 흐름 배속. 1.0이면 실제 시간과 동일 속도(2.0이면 2배속 시뮬레이션 등으로 추정)
        { name = "TIME_SCALE", value = "1.0" },

        # 의도적으로 손상된(비정상) 로그를 섞는 비율 (0.03 = 3%)
        { name = "CORRUPTION_RATE", value = "0.03" },

        # 손상된 로그에 "이건 corruption이다"라는 라벨을 남길지 여부
        # false면 실제 운영 환경처럼 라벨 없이 섞임 (더 현실적인 노이즈 데이터)
        { name = "INCLUDE_CORRUPTION_LABEL", value = "false" },

        # 로그 출력 방식 - stdout이면 CloudWatch Logs로 그대로 수집됨
        { name = "OUTPUT_MODE", value = "stdout" },

        # (OUTPUT_MODE가 file 계열일 때 사용될 것으로 추정되는) 로그 파일 저장 경로
        # 현재 stdout 모드라 실제로 안 쓰일 가능성 있음 - 컨테이너 내부 임시 경로
        { name = "LOG_FILE", value = "/tmp/generated-logs.jsonl" },

        # 로그 타임스탬프 기준 시간대
        { name = "TIMEZONE", value = "Asia/Seoul" },

        # 가짜 데이터 생성 라이브러리(Faker)의 로케일 - 한국어/한국 지역 형식 데이터 생성
        { name = "FAKER_LOCALE", value = "ko_KR" },

        # 실행 환경 구분 태그 - 실제 운영이 아닌 시뮬레이션임을 명시
        { name = "ENVIRONMENT", value = "simulation" },

        # 이번 실행을 식별하는 ID - "manual"은 수동 트리거임을 나타냄
        # (스케줄러나 CI가 트리거하면 다른 값으로 구분할 수 있게 설계된 것으로 추정)
        { name = "RUN_ID", value = "manual" }
      ]


      # "stdout → CloudWatch Logs로 자동 전송"
      logConfiguration = {
        logDriver = "awslogs"

        options = {
          # 어느 Log Group에 쌓을지 - logs.tf에서 만든 CloudWatch Log Group 참조
          # EX) de-ai-22-loggen"
          "awslogs-group" = aws_cloudwatch_log_group.generator.name

          # 그 Log Group이 위치한 리전
          "awslogs-region" = var.aws_region

          # 로그 스트림 이름 앞에 붙는 접두사
          "awslogs-stream-prefix" = "generator"
        }
      }
    }
  ])
}