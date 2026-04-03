project              = "we11cloud"
environment          = "production"
region               = "sg-sin-2"
api_instance_type    = "g6-standard-2"
worker_instance_type = "g6-dedicated-4"
enable_worker        = false
app_port             = 3007
admin_ips            = [] # sau này thêm IP của bạn vào, ví dụ ["1.2.3.4/32"] để SSH được
authorized_keys      = [] # thêm SSH public key vào, ví dụ ["ssh-rsa AAAA..."]

# Sensitive vars (token, key, secret) KHÔNG viết ở đây — truyền qua env TF_VAR_*