# ECS -> Cloudwatch => S3, Kinesis, . . . 외부 연결은 우선 X
resource "aws_security_group" "fargate" {
  name = "${var.project_name}-fargate-sg"
  description = "외부 연결 없이 Fargate 전용"
  vpc_id = aws_vpc.this.id


  tags = {
    "Name" = "${var.project_name}-fargate-sg"
  }
}

#  ECR 푸시, Cloudwatch Log 전송 => 아웃바운드 허용
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.fargate.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1" # 모든 프로토콜에 대응
}