# Terraform tự hiểu dependency graph: storage và network chạy song song (không phụ thuộc nhau), compute chờ network xong (vì cần subnet_id)
module "storage" {
  source = "./modules/storage"

  project        = var.project
  environment    = var.environment
  region         = var.region
  api_gateway_ip = module.compute.api_gateway_ip
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
  redis_instance_type  = var.redis_instance_type
  enable_worker        = var.enable_worker
  app_port             = var.app_port
  admin_ips            = var.admin_ips
  root_password        = var.root_password
  redis_password       = var.redis_password
  authorized_keys      = var.authorized_keys
}
