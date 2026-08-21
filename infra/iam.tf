# Fargate는 ECR TASK(로그 생성)를 생성하여 CloudWatch에 저장
# ECR에 등록된 이미지(PUSH 작업 진행), CloudWatch에 저장(로그 전송) -> 2개 권한 필요

# 1. ECR TASK policy 조회(어떤 것이 가능-> xx.amazon.com )
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
# 2. 해당 Role 정의(생성)
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project_name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# 3. Role, 정책 연결 마무리, 실제 실행시 필요한 권한 부여!!
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role = aws_iam_role.ecs_execution.name

  # AWS 관리형 정책을 사전에 AmazonECSTaskExecutionRolePolicy 구성
  # -> [가능] Fargate는 ECR TASK(로그 생성)를 생성하여 CloudWatch에 저장
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================
# 브론즈 - Firehose용 IAM Role/Policy 설정
# Firehose가 "누구 대신 행동할 수 있는지"(1) 정의하고,
# "무엇을 할 수 있는지"(2) 정의한 뒤, 이 둘을 연결(3)하는 3단계 구조
# ============================================

# --- 1단계: "누가 이 Role을 맡을 수 있는가" (Trust Policy / AssumeRole) ---
# ECS Task와 동일한 패턴. 다만 principal이 ecs-tasks.amazonaws.com이 아니라
# firehose.amazonaws.com으로, "Firehose 서비스만 이 Role을 assume할 수 있다"는 뜻
data "aws_iam_policy_document" "firehose_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

# 위에서 정의한 Trust Policy를 기반으로 실제 IAM Role 생성
# 이 시점엔 아직 "무엇을 할 수 있는지"는 없고, "Firehose가 이 Role을 쓸 수 있다"만 정해진 상태
resource "aws_iam_role" "firehose" {
  name = "${var.project_name}-firehose-role"

  # Role을 맡을 수 있는 대상(principal)을 정의한 정책 → .json으로 실제 JSON 문자열 참조
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

# --- 2단계: "이 Role이 실제로 무엇을 할 수 있는가" (Permissions Policy) ---
# Firehose가 입력으로 Kinesis(KDS)에서 읽어오고, 출력으로 S3에 저장할 수 있는 권한 정의
# (kinesis:GetRecords, kinesis:DescribeStream, s3:PutObject 등이 여기 들어갈 예정 - 내용은 추후 작성)
data "aws_iam_policy_document" "firehose_s3" {
  # kinesis 읽기 권한 관련  
  statement {
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [
      aws_kinesis_stream.bronze.arn
    ]
  }
  # s3 저장 권한 관련
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.data.arn,       # 해당 버킷
      "${aws_s3_bucket.data.arn}/*" # 해당 버킷 이하 모든 경로
    ]
  }
}

# --- 3단계: 1단계에서 만든 Role에 2단계에서 정의한 권한(policy)을 실제로 연결 ---
# 이 단계가 완료돼야 비로소 firehose Role이 "Firehose를 맡을 수 있고 + Kinesis/S3에 접근 가능한" 상태가 됨
resource "aws_iam_role_policy" "firehose" {
  name   = "${var.project_name}-firehose-s3-policy"
  role   = aws_iam_role.firehose.name                    # Role 리소스의 .name 속성 참조
  policy = data.aws_iam_policy_document.firehose_s3.json # Policy document의 .json 속성 참조
}


# ecs -> task 에서 kinesis 전송시 role을 별도 추가
# ecs task role
# execute role (기존, task 실행 권한)
# kinesis role (신규추가, kinesis로 데이터 putRecord 권한)

# ecs task -> data -> kinesis 권한 부여하기위한 role 구성
# 기본적으로 ecs_tasks_assume 부여
resource "aws_iam_role" "ecs_task_kinesis" {
  name               = "${var.project_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# ecs task -> data -> kinesis 권한 조회
data "aws_iam_policy_document" "ecs_task_kinesis" {
  statement {
    effect = "Allow"

    actions = [
      "kinesis:PutRecords",
      "kinesis:PutRecord"
    ]

    resources = [
      aws_kinesis_stream.bronze.arn
    ]
  }
}

# role에 연결하여 정책 구성
resource "aws_iam_role_policy" "ecs_task_kinesis" {
  name   = "${var.project_name}-kinesis-write"
  role   = aws_iam_role.ecs_task_kinesis.id
  policy = data.aws_iam_policy_document.ecs_task_kinesis.json
}