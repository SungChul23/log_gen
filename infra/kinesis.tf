resource "aws_kinesis_stream" "bronze" {
  name             = local.kinesis_stream_name
  shard_count      = var.KDS_shard_count
  retention_period = var.kinesis_retention_hour

  # 구성 방식 - 프로비저닝으로 할당
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    DataLayer = "bronze"
  }
}
