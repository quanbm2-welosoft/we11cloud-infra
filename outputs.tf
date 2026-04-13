# Điền .env cho NestJS
output "nestjs_env" {
  description = "Env vars cho NestJS"
  value = {
    LINODE_ENDPOINT = module.storage.storage_endpoint
    LINODE_REGION   = var.region
    BUCKET_NAME     = module.storage.ingest_raw_bucket
  }
}

output "nestjs_access_key" {
  value = module.storage.nestjs_access_key
}

output "nestjs_secret_key" {
  value     = module.storage.nestjs_secret_key
  sensitive = true
}

output "worker_access_key" {
  value = module.storage.worker_access_key
}

output "worker_secret_key" {
  value     = module.storage.worker_secret_key
  sensitive = true
}

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

output "redis_ip" {
  description = "Public IP cua Redis"
  value       = module.compute.redis_ip
}
