variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "리소스 이름에 사용할 프로젝트명"
  type        = string
  default     = "de-ai-22-loggen"
}

#############################
# 네트워크 구성
#############################

variable "vpc_cidr" {
  description = "VPC CIDR, Fargate 전용"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public Subnet CIDR 목록, Fargate task 작동시 매번 다른 가용영역 사용"
  type        = list(string)

  # 멀티 AZ 염두
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  # 유효성 검사
  validation {
    condition     = length(var.public_subnet_cidrs) >= 1
    error_message = "최소 1개 퍼블릭 서브넷 CIDR 필수"
  }
}


#############################
# Fargate 관련
#############################

# Fargate task CPU
variable "task_cpu" {
  deprecated = "CPU Unit -> 512 == 0.5 vCPU"
  type = number
  default = 512
}

# Fargate task MEM
variable "task_mem" {
  deprecated = "mem mib"
  type = number
  default = 1024
}

# Cloudwatch Log 보관 일수
variable "log_retention_days" {
    deprecated = "로그 1주일 보관"
    type = number
    default = 7
}

# ECS Task가 ECR 이미지 사용시 테그 -> latest
variable "image_tag" {
    deprecated = "task가 정의될때 참고하는 tag명"
    type = string
    default = "latest"
}
