terraform {
  required_version = ">= 1.5.0"
  # Đảm bảo ai trong team cũng dùng Terraform đủ mới

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2.25"
      # Linode Provider v3.0.0 có breaking changes — pin ~> 2.25 cho ổn định 
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # Chỉ dùng để gọi S3 API sang Akamai, không phải AWS thật
    }
  }
}