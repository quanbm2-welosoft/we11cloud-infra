output "api_gateway_ip" {
  value = linode_instance.api_gateway.ip_address
}

output "api_gateway_private_ip" {
  value = "10.0.1.10"
}

output "worker_ip" {
  value = var.enable_worker ? linode_instance.worker[0].ip_address : null
}

output "worker_private_ip" {
  value = var.enable_worker ? "10.0.1.20" : null
}

output "redis_private_ip" {
  value = "10.0.1.30"
}

output "redis_ip" {
  value = linode_instance.redis.ip_address
}
