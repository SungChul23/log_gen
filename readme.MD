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

