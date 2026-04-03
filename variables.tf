# Sensitive (truyền qua env: TF_VAR_xxx) 
variable "linode_api_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "linode_obj_access_key" {
  description = "Linode Object Storage access key (cho AWS provider)"
  type        = string
  sensitive   = true
}

variable "linode_obj_secret_key" {
  description = "Linode Object Storage secret key (cho AWS provider)"
  type        = string
  sensitive   = true
}

# Project

variable "project" {
  type    = string
  default = "we11cloud"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "region" {
  type    = string
  default = "sg-sin-2"
}

# Compute

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
  default   = ""
}

variable "authorized_keys" {
  type    = list(string)
  default = []
}