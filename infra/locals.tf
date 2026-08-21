locals {
  # 자동으로 계산하여 AZ 영역 결정 -> a,b 선택될 것임
  availability_zones = slice(
    data.aws_availability_zones.available.names, # 사용 가능한 AZ
    0,                                           # 시작 Index
    length(var.public_subnet_cidrs)              # 끝 Index
  )

  # 기타 이름 설정
  cluster_name    = "${var.project_name}-cluster"
  task_family     = "${var.project_name}-task"
  repository_name = "${var.project_name}-repo"
  log_group_name  = var.project_name

  # [브론즈 추가] - 키네시스 관련
  kinesis_stream_name = "${var.project_name}-kinesis"
  firehose_name       = "${var.project_name}-firehose"
}

# [실버 추가]
locals {
  silver_kinesis_stream_name  = "${var.project_name}-silver-kinesis"
  silver_firehose_name        = "${var.project_name}-silver-firehose"
  flink_application_name      = "${var.project_name}-silver-flink"
  flink_log_group_name        = "/aws/kinesis-analysis/${var.project_name}-silver-flink"
}

