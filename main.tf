terraform {
  backend "s3" {
    bucket = "we11-ingest-raw"
    key    = "we11cloud/terraform.tfstate"
    region = "sg-sin-2"

    endpoints = {
      s3 = "https://sg-sin-2.linodeobjects.com"
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

# Terraform tự hiểu dependency graph: storage và network chạy song song (không phụ thuộc nhau), compute chờ network xong (vì cần subnet_id)
module "storage" {
  source = "./modules/storage"

  project     = var.project
  environment = var.environment
  region      = var.region
}

module "network" {
  source = "./modules/network"

  project     = var.project
  environment = var.environment
  region      = var.region
}

module "compute" {
  source = "./modules/compute"

  project     = var.project
  environment = var.environment
  region      = var.region

  # module.network.subnet_id — đây là chỗ nối: network output → compute input
  subnet_id            = module.network.subnet_id
  api_instance_type    = var.api_instance_type 
  worker_instance_type = var.worker_instance_type
  enable_worker        = var.enable_worker
  app_port             = var.app_port
  admin_ips            = var.admin_ips
  root_password        = var.root_password
  authorized_keys      = var.authorized_keys
}