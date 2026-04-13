resource "linode_instance" "api_gateway" {
  label  = "${var.project}-api-${var.environment}"
  region = var.region
  type   = var.api_instance_type
  image  = "linode/ubuntu24.04"
  # g6-standard-2 = 4GB RAM, 2 CPU — đủ cho NestJS + ClamAV


  root_pass       = var.root_password
  authorized_keys = var.authorized_keys

  # 2 interface: public (nhận request từ internet) + VPC (giao tiếp nội bộ với worker qua IP 10.0.1.10)
  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc = "10.0.1.10"
    }
  }

  metadata {
    user_data = base64encode(templatefile("${path.module}/templates/api-gateway-userdata.sh", {
      app_port = var.app_port
    }))
  }
  # templatefile() — đọc file shell script và thay biến ${app_port} trước khi truyền vào
  # base64encode() — Linode metadata yêu cầu userdata phải encode base64

  tags = [var.project, var.environment, "api"]
}

resource "linode_instance" "worker" {
  # mặc định false = 0 server, Week 2 đổi thành true = tạo 1 server. Sau này scale lên 10 chỉ cần đổi số
  count = var.enable_worker ? 1 : 0

  #g6-dedicated-4 = 8GB RAM, 4 dedicated CPU — cần CPU mạnh cho FFmpeg transcode
  label  = "${var.project}-worker-${var.environment}"
  region = var.region
  type   = var.worker_instance_type
  image  = "linode/ubuntu24.04"

  root_pass       = var.root_password
  authorized_keys = var.authorized_keys

  interface {
    purpose = "public"
  }

  # VPC IP 10.0.1.20 — API Gateway (10.0.1.10) gọi Worker qua IP này
  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc = "10.0.1.20"
    }
  }

  metadata {
    user_data = base64encode(templatefile("${path.module}/templates/worker-userdata.sh", {}))
  }

  tags = [var.project, var.environment, "worker"]
}

resource "linode_instance" "redis" {
  label  = "${var.project}-redis-${var.environment}"
  region = var.region
  type   = var.redis_instance_type
  image  = "linode/ubuntu24.04"

  root_pass       = var.root_password
  authorized_keys = var.authorized_keys

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc = "10.0.1.30"
    }
  }

  metadata {
    user_data = base64encode(templatefile("${path.module}/templates/redis-userdata.sh", {
      redis_password   = var.redis_password
      redis_private_ip = "10.0.1.30"
    }))
  }

  tags = [var.project, var.environment, "database"]
}

resource "linode_firewall" "api_gateway" {
  label = "${var.project}-fw-api-${var.environment}"

  # 80,443 mở public (HTTP, HTTPS) cho user truy cập
  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # 3310 chỉ mở cho VPC (10.0.1.0/24) — ClamAV scan virus, chỉ internal gọi được
  inbound {
    label    = "allow-clamav-vpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "3310"
    ipv4     = ["10.0.1.0/24"]
  }

  # 22 (SSH) chỉ mở cho admin_ips — nếu list trống thì rule này không tạo (dynamic block)
  dynamic "inbound" {
    for_each = length(var.admin_ips) > 0 ? [1] : []
    content {
      label    = "allow-ssh-admin"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "22"
      ipv4     = var.admin_ips
    }
  }

  # inbound_policy = "DROP" — mọi traffic khác bị chặn hết (whitelist approach)
  inbound_policy = "DROP"

  # outbound_policy = "ACCEPT" — cho phép server gọi ra ngoài (tải package, gọi API...)
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.api_gateway.id]
}

resource "linode_firewall" "worker" {
  count = var.enable_worker ? 1 : 0

  label = "${var.project}-fw-worker-${var.environment}"

  # Worker chủ động pull job từ Redis (outbound) — không cần mở inbound port nào từ VPC.
  # Nguyên tắc least-privilege: KHÔNG mở dải 1-65535. Nếu sau này cần expose health-check
  # HTTP cho gateway, thêm rule allow port cụ thể (ví dụ 8080) tại đây — chỉ từ 10.0.1.10/32.

  dynamic "inbound" {
    for_each = length(var.admin_ips) > 0 ? [1] : []
    content {
      label    = "allow-ssh-admin"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "22"
      ipv4     = var.admin_ips
    }
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  # linode_instance.worker[0].id — vì dùng count, phải truy cập bằng index [0]
  linodes = [linode_instance.worker[0].id]
}

resource "linode_firewall" "redis" {
  label = "${var.project}-fw-redis-${var.environment}"

  inbound {
    label    = "allow-redis-vpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "6379"
    ipv4     = ["10.0.1.10/32", "10.0.1.20/32"]
  }

  dynamic "inbound" {
    for_each = length(var.admin_ips) > 0 ? [1] : []
    content {
      label    = "allow-ssh-admin"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "22"
      ipv4     = var.admin_ips
    }
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.redis.id]
}
