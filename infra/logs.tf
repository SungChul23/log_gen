# Fargate을 통해 task 작동 -> stdout/stderr 등 발생 -> Cloudwatch에 저장
resource "aws_cloudwatch_log_group" "generator" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
}