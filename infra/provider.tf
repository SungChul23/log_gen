provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project  = var.project_name
      ManageBy = "Terraform"
      Purpose  = "로그 재너레이터"
    }
  }
}

# 가용영역 조회
data "aws_availability_zones" "available" {
  state = "available"
}

# [브론즈 추가] aws account ID 조회
data "aws_caller_identity" "current" {
  
}