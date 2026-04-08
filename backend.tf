# terraform {
#   backend "s3" {
#     bucket = "we11-tf-state"
#     key    = "we11cloud/terraform.tfstate"
#     region = "sg-sin-2"

#     endpoints = {
#       s3 = "https://sg-sin-2.linodeobjects.com"
#     }

#     # Bắt buộc khi dùng S3-compatible (không phải AWS thật)
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     skip_requesting_account_id  = true
#     use_path_style              = true
#   }
# }
