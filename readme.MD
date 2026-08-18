# 목표
- AWS Fargate를 이용한 로그 생성기
    - AWS Fargate
        - EC2 사용/관리 X
        - ECR에 등록된 이미지를 이용하여 ECS에 직접 컨테이너 실행 -> `서버리스`로 실행환경 제공 
        - 비용 저렴
    - 발생된 데이터
        - 데이터 형태 : 요청 -> 서비스 대응 -> 응답 -> 합친 최종 로그 
        - 데이터 저장 
            - s3
            - cloudwatch
            - file
            - 콘솔

# 인프라 구성
- variables.tf
- version.tf
- provider.tf
- locals.tf
- vpc.tf
- iam.tf
- ecr.tf
- ecs.tf
- outputs.tf
- logs.tf