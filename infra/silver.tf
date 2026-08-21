# [실버 추가]
# 실버 레이어에서 사용되는 키네시스
# Flink(실시간 정재) -> KDF 전송

resource "aws_kinesis_stream" "silver" {
  name             = local.silver_kinesis_stream_name
  shard_count      = var.silver_kinesis_shard_count
  retention_period = var.silver_kinesis_retention_hour

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
  tags = {
    DataLayer = "silver"
  }
}