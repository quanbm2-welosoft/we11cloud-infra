# Secret keys đánh dấu sensitive = true — Terraform sẽ ẩn giá trị trong output, chỉ xem được bằng terraform output -raw nestjs_secret_key
# Các output này sẽ được root module export ra để điền vào .env của NestJS

output "ingest_raw_bucket" {
  value = linode_object_storage_bucket.ingest_raw.label
}

output "delivery_hls_bucket" {
  value = linode_object_storage_bucket.delivery_hls.label
}

output "storage_endpoint" {
  value = "https://${var.region}.linodeobjects.com"
}

output "nestjs_access_key" {
  value = linode_object_storage_key.nestjs.access_key
}

output "nestjs_secret_key" {
  value     = linode_object_storage_key.nestjs.secret_key
  sensitive = true
}

output "worker_access_key" {
  value = linode_object_storage_key.worker.access_key
}

output "worker_secret_key" {
  value     = linode_object_storage_key.worker.secret_key
  sensitive = true
}