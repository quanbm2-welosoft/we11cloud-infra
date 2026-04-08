variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "api_gateway_ip" {
  type        = string
  default     = ""
  description = "Public IP of API Gateway - dùng cho IP-based bucket policy"
}
