# 목표
- AWS Fargate를 이용한 log 생성기
    - AWS Fargate
        - EC2 사용/관리 X
        - ECR에 등록된 이미지를 이용하여 ECS에 직접 컨테이너 실행 -> `서버리스`로 실행환경 제공 
        - 비용 저렴
    - 발생된 데이터
        - 데이터 형태 : 요청 -> 서비스 대응 -> 응답 -> 합친 최종 log
        - 데이터 저장 
            - s3
            - cloudwatch
            - file
            - 콘솔

# 인프라 구성
- variables.tf    : 리전, 프로젝트명, CPU/MEM 등 구성 조정용 입력 변수 선언
- version.tf      : Terraform 버전, AWS provider 버전 제약(required_providers, required_version)
- provider.tf     : AWS provider 설정 (region, profile/credentials 등)
- locals.tf       : 테라폼에 사용하는 공통값, 태그, 프로젝트명 등 계산된 상수 정의
- vpc.tf          : 전용 네트워크, VPC, Subnet, IGW, RT, SG, AZ, NAT(우선 제외)
- sg.tf           : 보안그룹 (우선 외부 연결 X) -> ingress 미지정 
- iam.tf          : Fargate Task Execution Role(ECR 이미지 GET, CloudWatch 로그 기록 권한) + Task Role(태스크 자체 런타임 권한, 필요 시)
- ecr.tf          : log 생성용 컨테이너 이미지 저장 리포지토리
- ecs.tf          : ECS 클러스터, Task Definition, Service 등 Fargate 실행 환경 정의
- logs.tf         : ECS 컨테이너 내 발생 로그 → CloudWatch Log Group 지정 (log group, retention 등)
- outputs.tf      : 생성 후 각종 정보(ECR URI, ECS 서비스명, 로그 그룹명 등) 추출

# 테라폼 주요 명령어
```
> ~/infra
> terraform init
> terraform fmt
> terraform vaildate
> terraform plan
> terraform apply
```

# 로그 생성기 (~/generator)
## 로그 포멧 (공통)
- 서비스 요청에 따른 처리가 완료된후 로그로 기록하는 최종 필드를 포함한 데이터 샘플
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
  "service": {...},
  "client": {...},
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
  "data": {... domain specific ...}  <- 도메인별로 커스텀 구성
}
```

## 지원 도메인 및 이벤트 정의
- domain으로 카테고리 설정
- 각 도메인들을 이벤트 비율 조정, 시간대별로 발생량을 조절, 주요 필드 설정

| DOMAIN | 주요 이벤트 예시 |
|---|---|
| `ecommerce` | product_view, search, add_to_cart, checkout, order_created, payment_completed |
| `finance` | account_login, balance_inquiry, card_payment, transfer, deposit, withdrawal |
| `smartfactory` | sensor_reading, equipment_state, quality_inspection, alarm, maintenance_event |
| `game` | login, session_heartbeat, match_started, match_finished, item_purchase, quest_completed |    


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