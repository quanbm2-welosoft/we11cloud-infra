variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_id" {
  description = "VPC Subnet ID từ network module"
  type        = number
}

variable "api_instance_type" {
  type    = string
  default = "g6-standard-2"
}

variable "worker_instance_type" {
  type    = string
  default = "g6-dedicated-4"
}

variable "enable_worker" {
  type    = bool
  default = false
}

variable "app_port" {
  type    = number
  default = 3007
}

variable "admin_ips" {
  type    = list(string)
  default = []
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "authorized_keys" {
  type    = list(string)
  default = []
}

variable "redis_instance_type" {
  type    = string
  default = "g6-standard-1"
}

variable "redis_password" {
  type      = string
  sensitive = true
} 
