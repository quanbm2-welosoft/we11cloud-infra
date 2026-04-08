project              = "we11cloud"
environment          = "staging"
region               = "sg-sin-2"
api_instance_type    = "g6-nanode-1"
worker_instance_type = "g6-standard-2"
enable_worker        = false
app_port             = 3007
admin_ips            = []
authorized_keys      = []
storage_endpoint     = "https://sg-sin-1.linodeobjects.com"

# Staging dùng instance nhỏ hơn (nanode-1) để tiết kiệm chi phí test.
