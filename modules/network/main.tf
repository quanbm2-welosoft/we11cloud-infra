# VPC — mạng riêng ảo, các server trong cùng VPC giao tiếp qua private IP, không đi qua internet
# 10.0.1.0/24 — dải 256 IP nội bộ (10.0.1.0 → 10.0.1.255), đủ dùng cho project
# linode_vpc.main.id — subnet tham chiếu đến VPC vừa tạo, Terraform tự hiểu phải tạo VPC trước

resource "linode_vpc" "main" {
  label       = "${var.project}-vpc"
  region      = var.region
  description = "${var.project} ${var.environment} VPC"
}

resource "linode_vpc_subnet" "app" {
  vpc_id = linode_vpc.main.id
  label  = "${var.project}-app-subnet"
  ipv4   = "10.0.1.0/24"
}