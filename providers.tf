# Quản lý compute, VPC, firewall, buckets, access keys
provider "linode" {
  token = var.linode_api_token
}

# Trick quan trọng nhất,  Akamai object storage tương thích S3 API, nên dùng AWS provider nhưng trỏ endpoint sang Linode
provider "aws" {
  region     = "sg-sin-2" // dummy value, AWS provider bắt buộc phải có nhưng không ảnh hưởng gì 
  access_key = var.linode_obj_access_key
  secret_key = var.linode_obj_secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  # Tắt hết validation của AWS vì không phải AWS thật

  endpoints {
    s3 = "https://${var.region}.linodeobjects.com" // Gọi sang Akamai
  }
}