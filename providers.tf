# Quản lý compute, VPC, firewall, buckets, access keys
provider "linode" {
  token = var.linode_api_token
}

# Trick quan trọng nhất,  Akamai object storage tương thích S3 API, nên dùng AWS provider nhưng trỏ endpoint sang Linode
provider "aws" {
  region     = "us-east-1"
  access_key = var.linode_obj_access_key
  secret_key = var.linode_obj_secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  s3_use_path_style = true

  endpoints {
    s3 = var.storage_endpoint
  }
}
