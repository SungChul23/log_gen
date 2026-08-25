# log-gen

AWS Fargate 기반의 실전형 로그 생성기입니다. 여러 도메인(이커머스, 금융, 스마트팩토리, 게임)에서 발생할 법한 `요청 → 처리 → 응답` 흐름의 애플리케이션 로그를 실제와 유사한 패턴으로 지속 생성하며, Kinesis Data Streams(KDS)와 Kinesis Data Firehose(구 KDF)를 통해 S3에 적재하는 스트리밍 수집 파이프라인을 구축했습니다. 

- Bronze 레이어(원본 보존)를 시작으로 Silver, Gold로 이어지는 `메달리온 아키텍처(Medallion Architecture)`를 적용하여, 이후 데이터 엔지니어링 파이프라인(Airflow 등 오케스트레이션 도구)의 입력 데이터로 활용하는 것을 목표로 합니다.

## 목표

- **AWS Fargate**를 이용한 로그 생성기 구축
  - EC2를 직접 사용/관리하지 않는 서버리스 컴퓨트 환경
  - ECR에 등록된 컨테이너 이미지를 ECS Task로 직접 실행
  - 사용한 리소스(vCPU/메모리)만큼만 과금되는 구조
- 생성된 로그는 아래와 같은 대상으로 저장 가능하도록 설계
  - S3
  - CloudWatch Logs
  - 로컬 파일
  - 콘솔(stdout)

## 아키텍처

```
[ECR: 컨테이너 이미지 저장]
        ↓
[ECS Task Definition: Fargate 실행 스펙 정의]
        ↓
[ECS Cluster + Fargate: 서버리스로 컨테이너 실행]
        ↓
[로그 생성기 컨테이너 동작]
        ↓
[CloudWatch Logs / S3 등으로 로그 적재]
```

- 컴퓨트: **AWS Fargate** (EC2 관리 불필요, ECS Task 단위로 실행)
- 네트워크: 전용 VPC + 퍼블릭 서브넷(멀티 AZ) + IGW (NAT 미사용, 우선 제외)
- 이미지 저장소: ECR (Task가 참조하는 컨테이너 이미지)
- 권한: IAM Task Execution Role (ECR 이미지 GET, CloudWatch 로그 기록)
- 로그: CloudWatch Log Group (retention 설정)

## 인프라 구성 (Terraform)

```
infra/
├── variables.tf    # 리전, 프로젝트명, CPU/MEM 등 입력 변수
├── version.tf      # Terraform / AWS Provider 버전 제약
├── provider.tf     # AWS Provider 설정 (region 등)
├── locals.tf       # 공통값, 태그, 프로젝트명 등 계산된 상수
├── vpc.tf          # VPC, Subnet, IGW, RT, AZ (NAT 우선 제외)
├── sg.tf           # 보안그룹 (우선 외부 인바운드 미허용)
├── iam.tf          # ECS Task Execution Role / Task Role, Firehose Role
├── ecr.tf          # 로그 생성기 컨테이너 이미지 저장소
├── ecs.tf          # ECS 클러스터, Task Definition, Service
├── kinesis.tf       # Kinesis Data Stream (KDS)
├── firehose.tf      # Kinesis Data Firehose (KDF) 배달 스트림
├── s3.tf            # Bronze 레이어 데이터 저장 버킷
├── logs.tf          # CloudWatch Log Group 설정
└── outputs.tf       # ECR URI, 서비스명, 로그 그룹명 등 출력
```


### 실행 명령어

```bash
cd infra
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

## 로그 생성기 (`generator/`)

### 로그 포맷 (공통 스키마)

모든 도메인 공통으로 아래 필드 구조를 따르며, `data` 필드만 도메인별로 다르게 구성됩니다.

```json
{
  "schema_version": "1.0",
  "record_type": "application_log",
  "event_id": "...",
  "trace_id": "...",
  "run_id": "...",
  "occurred_at": "2026-08-12T16:30:11.123+09:00",
  "generated_at_utc": "2026-08-12T07:30:11.123+00:00",
  "domain": "ecommerce",
  "event_type": "order_created",
  "service": { "..." },
  "client": { "..." },
  "request": {
    "method": "POST",
    "path": "/api/orders",
    "request_bytes": 1234
  },
  "response": {
    "status_code": 201,
    "latency_ms": 287,
    "response_bytes": 3590
  },
  "data": { "...": "도메인별 커스텀 필드" }
}
```

### 지원 도메인

| DOMAIN | 주요 이벤트 예시 |
|---|---|
| `ecommerce` | product_view, search, add_to_cart, checkout, order_created, payment_completed |
| `finance` | account_login, balance_inquiry, card_payment, transfer, deposit, withdrawal |
| `smartfactory` | sensor_reading, equipment_state, quality_inspection, alarm, maintenance_event |
| `game` | login, session_heartbeat, match_started, match_finished, item_purchase, quest_completed |

### 실제와 유사한 발생 패턴 시뮬레이션

단순 랜덤 생성이 아닌, 아래 조건을 고려한 시간대별 발생량 조절을 지원합니다.

- 시간대별 가중치
- 평일 / 주말 가중치
- 간헐적 트래픽 상승(버스트) 반영

| DOMAIN | 패턴 |
|---|---|
| ecommerce | 점심/저녁 시간대 증가, 주말 감소 |
| finance | 평일 주간 시간 증가, 주말 감소 |
| smartfactory | 24시간 비교적 일정, 교대/주말에 변화 |
| game | 저녁/야간 피크, 주말 증가세 |

### 주요 환경변수

| 변수명 | 설명 |
|---|---|
| `DOMAIN` | 생성할 로그 도메인 |
| `DURATION_SECONDS` | 실행 지속 시간(초) |
| `MAX_EVENTS` | 최대 생성 이벤트 수 (0 = 무제한) |
| `BASE_RPS` | 기준 초당 이벤트 발생률 |
| `TIME_SCALE` | 시간 흐름 배속 |
| `CORRUPTION_RATE` | 의도적 손상 로그 비율 |
| `OUTPUT_MODE` | 출력 방식 (stdout / file 등) |
| `TIMEZONE` | 타임스탬프 기준 시간대 |
| `FAKER_LOCALE` | 가짜 데이터 생성 로케일 |

## 로드맵

- [x] Terraform으로 Fargate 인프라 구성 / 26.8.18
- [x] ECR 이미지 기반 ECS Task 실행 환경 구축 / 26.8.18
- [ ] ECS Service를 통한 상시 실행 및 오토스케일링
- [ ] Airflow와 연동하여 생성된 로그를 정제/적재하는 파이프라인 구축

# 실제와 유사한 발생 간격
- 고려 조건
    - 시간대별 가중치
    - 평일/주말 가중치
    - 간혈적 등장 부스터 (트래픽 상승)
    - . . .

- EX)
    - 이커머스 : 점심/저녁 시간대 증가, 주말 감소
    - 금융 : 평일 주간 시간증가, 주말 감소
    - 스마트팩토리 : 24시간 비교적 일정, 교대/주말 변화
    - 게임 : 저녁/야간 피크, 주말 증가세 
    - . . .


# 오염 데이터
- 비율 지정 => 0.03 => 각 이벤트에서 3% 비율로 오염 데이터 생산 => ETL에서 clean 작업 처리
- 오염 유형
```
missing_field
null_required
wrong_type
invalid_timestamp
numeric_outlier
invalid_enum
negative_latency
duplicate
malformed_json
```

# 로그 발생기의 데이터 파이프라인상의 포지션
```
                    Data Source Simulator
                   (Fargate + Python/Faker)
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
             S3          Kinesis         Kafka
        (File/Batch)  (AWS Stream)   (Event Stream)
              │             │             │
              └─────────────┼─────────────┘
                            ▼
                       Bronze Layer
                            │
                    ETL / ELT Processing
                  (Pandas / Polars / Spark)
                            │
                       Silver Layer
                            │
                        Gold Layer
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
          Athena      OpenSearch          BI
```

# 제너레이터 구조 및 설치
```
~/generator
 L app
    L domains
      L *.py        : 4개 도메인에 대한 로그 생성 메인 제너레이터 함수
    L *.py          : main.py 로그 생성기 메인코드, 각종 기능 처리
 L Dockerfile       : 컨테이너 기반이 되는 이미지 생성용, ECR 푸시됨
 L requirements.txt : 필요 패키지
```


- 설치
```
# 루트 위치에서
pip install -r generator/requirements.txt
```

# 스크립트 
- setup.bat
```
  Terraform init
      ↓
  Terraform apply
      ↓
  ECR Repository 생성
  ECS/Fargate 관련 인프라 생성
      ↓
  AWS ECR 로그인
      ↓
  Docker 이미지 Build
      ↓
  ECR에 latest 이미지 Push
```

- run-local.bat
- 로컬 PC에서 로그 생성 (로컬 테스트)
```
  # 문법
  scripts\run-local.bat [DOMAIN] [DURATION] [RPS] [CORRUPTION] [OUTPUT] [TIME_SCALE]

  # 샘플 
  scripts\run-local.bat finance 60 5 0.05 both 1

  # 해석
  finance 도메인 로그 생성
  ↓
  60초 동안 실행
  ↓
  평균 5 RPS 속도로 생성된다
  ↓
  5% 오엽 데이터를 구성
  ↓
  출력은 stdout, file, both(둘다)
  file은 output 폴더 내부에 기록
  ↓
  시간 배율 조절은 1

```

- run-generator.bat
  - AWS fargate에서 진행
```
  # 전체 옵션
  scripts\run-generator.bat [DOMAIN] [DURATION] [BASE_RPS] [CORRUPTION_RATE] [TASK_COUNT] [REGION] [TIME_SCALE]

  # 처리흐름

  ┌──────────────────┐
│   로컬 PC 명령    │
│  (AWS CLI run-task) │
└─────────┬─────────┘
          │
          ▼
┌──────────────────┐
│   AWS ECS API     │
│  run-task 요청     │
└─────────┬─────────┘
          │
          ▼
┌──────────────────┐
│   ECS 클러스터     │
│  (실행 환경 제공)   │
└─────────┬─────────┘
          │
          ▼
┌──────────────────┐
│  Fargate Task 가동  │
│  (서버리스 컴퓨트)   │
└─────────┬─────────┘
          │
          ▼
┌──────────────────┐
│  Docker Container  │
│  (이미지 기반 실행)  │
└─────────┬─────────┘
          │
          ▼
┌──────────────────┐
│  Python 로그 생성기 │
│  (도메인별 이벤트 생성)│
└─────────┬─────────┘
          │
          ▼
┌──────────────────┐
│  CloudWatch Logs   │
│  (stdout → 자동 수집) │
└──────────────────┘



  # 명령어 샘플
  scripts\run-generator.bat ecommerce 2 5 0.05 1 ap-northeast-2 1    
  ---
  ============================================================
  Fargate synthetic log generator
  ============================================================
  Run ID          : loggen-2251219129-932
  Domain          : ecommerce
  Duration        : 2s
  Base RPS        : 5
  Time scale      : 1
  Corruption rate : 0.05
  Tasks           : 1
  Region          : ap-northeast-2
  Cluster         : de-ai-22-loggen-cluster

  -----------------------------------------------------------------------------------------------------------       
  |                                                 RunTask                                                 |
  +---------------------------------------------------------------------------------------------------------+
  |  arn:aws:ecs:ap-northeast-2:827913617635:task/de-ai-25-loggen-cluster/c79e8eb92b65483cb216e63afcee22d8  |
  +---------------------------------------------------------------------------------------------------------+


  Task started.
  Follow generated logs:
    aws logs tail "/ecs/de-ai-22-loggen" --follow --region "ap-northeast-2"


```
# 트레블 슈팅
```
# 등록된 리소스 확인
terraform state list

# AlreadyExists => 예전게 남아 있는 경우 
# 리소스 등록분에서 누락된 부분이 잇으면 수동 연결
# terraform import 리소스명 리소스값
terraform import aws_ecr_repository.generator de-ai-22-loggen-repo


```

# 확인
- 실시간 스트리밍 데이터 처리 관점
  - 실버 레벨 추가 부분
    - flink 앱 코드 확인
      - 추후 필요시 코드 업그레이드(기능 추가 부여)

    - 오염된 데이터 삭제(현재) => 별도 보관(저장) => 추후 해당 원인 분석 할수 있게 보관 (확장)
    - 저장데이터 -> jsonl (gzip) => parquet 저장(glue 사용)
    - flink 역활 lambda 대체 (차이점 이해)
  - 실버 -> 골드 추가
    - flink or lambda 사용 가능 => 최종 목표 형태로 가공
    - 중간 과정 동일
    - 최종 s3 적제(parquet) / opensearch
  - 대시보드 (프로메테우스, 그라파다 등 연결)
    - s3=>athena 쿼리질의, opensearch 검색질의 => 대시보드상 실시간 모니터링 데이터 조회에 응답가능

- 로그 생성기 => kinesis => firehose => s3(브론즈) 저장
  - 배치 프로세싱 (airflow 기반) + 메탈리온 아킥텍처 적용
    - 특정 주기 단위로 airflow 작동 => 브론즈 -> 실버 -> 골드 -> 최종 산출물(대시보드, 래포트) 구성

- 카프카 (뒤에서 체크)
- ELK, EFK
- step function, eventbridge 

# flink 앱 코드 확인
- 80% 코드 유지
  - 필요한 기능만 추가하는 구조로 활용
  - 함수에서 핵심 부분(정제, 전처리)만 커스텀 하면 기능 활용
  - 리소스가 변경되면 보정(설정값)

# 오염된 데이터 삭제(현재) => 별도 보관(저장)
## 개요
- 추후 해당 원인 분석 할수 있게 보관 (확장)
- 구성
```
Bronze Kinesis -> 배치 프로세싱으로 통해 오염 데이터만 추출하여 주기적으로 모니터링 방법
      ↓
    Flink
      │
      ├─ 정상 → Silver Kinesis → Firehose → S3 silver/
      │
      └─ 비정상 → Rejected Kinesis
                       ↓
                    Firehose
                       ↓
                  S3 rejected/ => 차후 배치 프로세싱을 통해 => 근본적인 문제 해결
```
- 정상과 비정상은 flink에서 연결
  - None으로 처리되는 부분을 Rejected Kinesis로 전달하도록 sql 수정
- Rejected Kinesis -> Firehose -> S3 rejected/ : 인프라 구성


## 인프라 구성
- 추가 및 수정
  - 인프라 구성 -> 적용
    - 대상 : kinesis 신규, kinesis->firehose, iam, flink, locals, variables, outputs    
  - flink 수정 -> 테스트 -> 오염데이터를 비율 30% 상승 -> 로그 발생 -> 오염데이터 저장 확인
- 실행 절차
  - flink 앱 빌드 + 인프라 업데이트 및 앱 배포
    ```
      scripts\setup-flink.bat
      
      sh ./scripts/setup-flink.sh

      ----
      scripts\flink-status.bat
      ----------------------------------------------------------
      |                   DescribeApplication                  |
      +-------------------------------+--------------+---------+
      |             Name              |   Runtime    | Status  |
      +-------------------------------+--------------+---------+
      |  de-ai-22-loggen-silver-flink |  FLINK-1_20  |  READY  |
      +-------------------------------+--------------+---------+

      -----
      scripts\flink-start.bat

      scripts\flink-status.bat
      # READY -> STARTING -> RUNNING

      ----- 
      # RUNNING 상태가 확인되면 -> 로그 발생, 오염도 30% 확대
      scripts\run-generator.bat ecommerce 30 10 0.30 1 ap-northeast-2 1

      -----
      # s3에서 reject 폴더 하위 데이터 확인

      -----
      # flink 중단
      scripts\flink-stop.bat
      -----
      # 중단 후 확인
      scripts\flink-status.bat
      ----------------------------------------------------------                                               
      |                   DescribeApplication                  |
      +-------------------------------+--------------+---------+
      |             Name              |   Runtime    | Status  |
      +-------------------------------+--------------+---------+
    ```
  - 로그 제너레이터 가동 -> 오염도를 30% 올려서 잘 수집되도록 구성


# parquet 저장 => 스키마 필요 => 열검색, 기반 => Glue 제공 (데이터베이스, 테이블, 크롤러, job등 다양하게 제공)
## glue
- 데이터에 관련된 통합 서비스
- 데이터를 구조를 정의, 이를 기반으로 쿼리 수행(골드 레이어 적합한 데이터 형태로 추출(집계, 통계,..=>분석))등 기반 제공
- 데이터베이스, 테이블, 스키마, 크롤러(데이터를 보고 자동으로 스키마 구성), ETL job 시각적 구성, ...

## parquet
- `대규모 빅데이터를 효율적으로 저장`하고 `빠르게 조회`하기 위해 만든 `열(Column) 기반 오픈소스 파일 포맷`
- 같은 양의 데이터를 더 작은 공간을 사용, 검색 더 빠르고, 호환 거의다 지원

## 인프라 수정/추가
- silver.tf의 firehose 저장 파트의 저장 부분 수정
  - silver layer를 통해 저장된 데이터 => 현재:gzip 파일, 대체:parquet 형태
  - compression_format = "GZIP" => UNCOMPRESSED
  - 압축 담당 SNAPPY 담당
- glue-silver.tf
  - s3 silver/.... 저장되는 parquet 데이터의 `스키마` 정의
  - json -> parquet 으로 변환할때 스키마 참조
  - Athena(raw데이터, parquet등 압축데이터를 대상으로 쿼리 가능)이 해당 파일을 대상으로 SQL 수행시 테이블/스키마 제공
  - s3 저장될대, 파티션 형태로 저장(year/month/day/hour)된 형태에서 sql 수행 가능(파티션 활용)
- iam-flink.tf
  - 기존 role에 glue 권한 추가
- outputs.tf
  - glue 관련 이름, 리소스등 출력