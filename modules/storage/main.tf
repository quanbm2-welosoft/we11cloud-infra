# Bucket riêng lưu Terraform state — TUYỆT ĐỐI không xóa
resource "linode_object_storage_bucket" "tf_state" {
  label  = "we11-tf-state"
  region = var.region
  acl    = "private"

  lifecycle {
    prevent_destroy = false # Chống xóa nhầm khi terraform destroy
  }
}

# Bucket chứa file gốc, không ai được đọc trực tiếp
resource "linode_object_storage_bucket" "ingest_raw" {
  label  = "we11-ingest-raw"
  region = var.region
  acl    = "private"

  # lifecycle {
  #   prevent_destroy = true # Chống xóa nhầm bucket khi chạy terraform destroy
  # }
}

# delivery-hls phục vụ HLS streaming, cần public
resource "linode_object_storage_bucket" "delivery_hls" {
  label  = "we11-delivery-hls"
  region = var.region
  acl    = "public-read"

  # lifecycle {
  #   prevent_destroy = true # Chống xóa nhầm bucket khi chạy terraform destroy
  # }
}

resource "linode_object_storage_bucket" "db_backups" {
  region = var.region
  label  = "we11-db-backups"
}

# read_write trên ingest-raw — NestJS upload video lên đây
resource "linode_object_storage_key" "nestjs" {
  label = "${var.project}-nestjs-${var.environment}"

  bucket_access {
    bucket_name = linode_object_storage_bucket.ingest_raw.label
    region      = var.region
    permissions = "read_write"
  }
}

# read_only trên ingest-raw (đọc video gốc) + read_write trên delivery-hls (ghi file HLS sau transcode)
resource "linode_object_storage_key" "worker" {
  label = "${var.project}-worker-${var.environment}"

  bucket_access {
    bucket_name = linode_object_storage_bucket.ingest_raw.label
    region      = var.region
    permissions = "read_only"
  }

  bucket_access {
    bucket_name = linode_object_storage_bucket.delivery_hls.label
    region      = var.region
    permissions = "read_write"
  }

  bucket_access {
    bucket_name = linode_object_storage_bucket.db_backups.label
    region      = var.region
    permissions = "read_write"
  }
}

# resource "aws_s3_bucket_lifecycle_configuration" "ingest_raw_expiry" {
#   bucket = linode_object_storage_bucket.ingest_raw.label

#   rule {
#     id     = "expire-raw-30d"
#     status = "Enabled"

#     expiration {
#       days = 30
#     }

#     filter {}
#   }
# }

# bucket policy là lớp bảo vệ bổ sung ngoài ACL

# ingest_raw_deny_public: dù ai đó lỡ đổi ACL thành public, policy này vẫn chặn GetObject
resource "aws_s3_bucket_policy" "ingest_raw_deny_public" {
  bucket = linode_object_storage_bucket.ingest_raw.label

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyPublicRead"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${linode_object_storage_bucket.ingest_raw.label}/*"
      }
    ]
  })
}

# delivery_hls_allow_public: cho phép mọi người đọc file HLS để stream
resource "aws_s3_bucket_policy" "delivery_hls_allow_public" {
  bucket = linode_object_storage_bucket.delivery_hls.label

  # viết policy dạng HCL, Terraform tự convert sang JSON
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${linode_object_storage_bucket.delivery_hls.label}/*"
      }
    ]
  })
}

# ==============================================================
# Security Posture: PutObject trên ingest-raw
# Hiện tại dùng Layered Security (Option B) thay vì IP-based Policy
#
# Layer 1: IAM Keys — nestjs key = read_write trên ingest-raw ONLY
#                      worker key = read_only trên ingest-raw
# Layer 2: Firewall — API Gateway chỉ mở 80/443/22, DROP hết traffic khác
# Layer 3: VPC      — Worker chỉ nhận traffic từ 10.0.1.0/24
# Layer 4: App      — ClamAV scan + workspaceId prefix enforced
# ==============================================================

# --- IP-based PutObject restriction (Option A) ---
# DISABLED: Akamai Object Storage không hỗ trợ aws:SourceIp condition.
# Khi Akamai hỗ trợ, uncomment block này và chạy:
#   terraform apply -var="api_gateway_ip=$(terraform output -raw api_gateway_ip)"
# resource "aws_s3_bucket_policy" "ingest_raw_ip_restrict" {
#   bucket = linode_object_storage_bucket.ingest_raw.label

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid       = "DenyPutFromUnknownIP"
#         Effect    = "Deny"
#         Principal = "*"
#         Action    = "s3:PutObject"
#         Resource  = "arn:aws:s3:::${linode_object_storage_bucket.ingest_raw.label}/*"
#         Condition = {
#           NotIpAddress = {
#             "aws:SourceIp" = [var.api_gateway_ip]
#           }
#         }
#       }
#     ]
#   })
# }
