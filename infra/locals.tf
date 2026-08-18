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
}