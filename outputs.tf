# Điền .env cho NestJS
output "nestjs_env" {
  description = "Env vars cho NestJS"
  value = {
    LINODE_ENDPOINT = module.storage.storage_endpoint
    LINODE_REGION   = var.region
    BUCKET_NAME     = module.storage.ingest_raw_bucket
  }
}

# Keys disabled — resources commented out in modules/storage/main.tf
# output "nestjs_secret_key" {
#   description = "Chạy: terraform output -raw nestjs_secret_key"
#   value       = module.storage.nestjs_secret_key
#   sensitive   = true
# }

output "worker_env" {
  description = "Env vars cho worker"
  value = {
    INGEST_BUCKET    = module.storage.ingest_raw_bucket
    DELIVERY_BUCKET  = module.storage.delivery_hls_bucket
    STORAGE_ENDPOINT = module.storage.storage_endpoint
  }
}

# output "worker_secret_key" {
#   description = "Chạy: terraform output -raw worker_secret_key"
#   value       = module.storage.worker_secret_key
#   sensitive   = true
# }

output "vpc_id" {
  value = module.network.vpc_id
}

output "api_gateway_ip" {
  description = "Public IP cua API Gateway"
  value       = module.compute.api_gateway_ip
}

output "worker_ip" {
  description = "Public IP cua Worker"
  value       = module.compute.worker_ip
}