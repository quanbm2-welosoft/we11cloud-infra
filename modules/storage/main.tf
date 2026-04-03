# Bucket chứa file gốc, không ai được đọc trực tiếp
resource "linode_object_storage_bucket" "ingest_raw" {
  label  = "we11-ingest-raw" 
  region = var.region
  acl    = "private" 

  lifecycle {
    prevent_destroy = true # Chống xóa nhầm bucket khi chạy terraform destroy
  }
}

# delivery-hls phục vụ HLS streaming, cần public
resource "linode_object_storage_bucket" "delivery_hls" {
  label  = "we11-delivery-hls"
  region = var.region
  acl    = "public-read" 

  lifecycle {
    prevent_destroy = true # Chống xóa nhầm bucket khi chạy terraform destroy
  }
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
}

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