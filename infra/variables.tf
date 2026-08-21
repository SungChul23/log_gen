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
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public Subnet CIDR 목록, Fargate task 작동시 매번 다른 가용영역 사용"
  type        = list(string)

  # 멀티 AZ 염두
  default = ["10.20.1.0/24", "10.20.2.0/24"]

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
  description = "CPU Unit -> 512 == 0.5 vCPU"
  type        = number
  default     = 512
}

# Fargate task MEM
variable "task_mem" {
  description = "mem mib"
  type        = number
  default     = 1024
}

# Cloudwatch Log 보관 일수
variable "log_retention_days" {
  description = "로그 1주일 보관"
  type        = number
  default     = 7
}

# ECS Task가 ECR 이미지 사용시 테그 -> latest
variable "image_tag" {
  description = "task가 정의될때 참고하는 tag명"
  type        = string
  default     = "latest"
}

##############[브론즈 추가]###############
# KDS
# shard의 갯수
# 프로비저닝 할당 <-> 온디멘드
variable "KDS_shard_count" {
  description = "KDS 샤드 수"
  type        = number
  default     = 1

}
# 데이터 보관 기관
variable "kinesis_retention_hour" {
  description = "샤드 내 데이터 보관기관"
  type        = number
  default     = 24
}

# KDF -> Amazone Data FireHose
# 어느정도 데이터가 모여야 보낼건지 (최소 1 MiB, 최대 128 MiB, 5 MiB을(를) 권장)
variable "firehose_buffer_size" {
  description = "해당 크기만큼 데이터가 쌓이면 강제 전송"
  type        = number
  default     = 1

}
# 몇초동안 모으고 보낼건지 (최소 0초 -> 최대 900초)
variable "firehose_buffer_interval" {
  description = "해당 시간만큼 데이터가 쌓이면 강제 전송"
  type        = number
  default     = 60

}
####################################

# [실버 추가]
# 실버 레이어에서 출력용 사드수
variable "silver_kinesis_shard_count" {
  description = "KDS's shard count"
  type        = number
  default     = 1
}
# kinesis 에서 미전송된 데이터 보관기간
variable "silver_kinesis_retention_hour" {
  description = "KDS's retention period in hours"
  type        = number
  default     = 24
}

# PyFlink 버전(런타임 환경의 버전) 1.20 사용
variable "flink_runtime_environment" {
  description = "Managed Service for Apache Flink의 런타임 환경버전"
  type        = string
  default     = "FLINK-1_20"
}
variable "flink_parallelism" {
  description = "Initial Flink application parallelism"
  type        = number
  default     = 1
}
variable "flink_parallelism_per_kpu" {
  description = "Flink parallel tasks per KPU"
  type        = number
  default     = 1
}

# flink 은 실행 시켜두어야만 실제 처리가 됨
# true : 인프라 적용되면 => 실행 => 실습 편의상 설정
# false : 실제 사용시 적용
variable "flink_start_application" {
  description = "Whether Terraform should start the Managed Flink application"
  type        = bool
  default     = true
}

# Flink를 가동한후 입력쪽(브론즈향) kinesis에서 데이터 읽을때 어디서 부터 처리할것인가? 설정
# 데이터는 계속해서 전송중 -> 추후 flink 가동 
# -> 가동 전에 도달한 데이터도 처리할것인가? flink 가동 이후 도착한 데이터만 처리할것인가?
# LATEST : flink 가둥 후 들어오는 데이터만 처리가
# TRIM_HORIZON : kinesis에 남아 있는 과거 로그 데이터 모두 처리 -> 재처리/테스트/전체 데이터(이전) 처리

variable "flink_source_init_poisition" {
  description = "flink가 데이터 처리시 입력원쪽의 어디서부터 처리할 것인가 설정"
  type        = string
  default     = "LATEST"

  # 변수의 값으로 올수 있는 내용들을 제약
  validation {
    # 오직 2가지만 허가됨
    condition = contains([
      "LATEST",
      "TRIM_HORIZON"
    ], var.flink_source_init_poisition)
    error_message = "flink_source_init_poisition is only LATEST or TRIM_HORIZON"
  }
}