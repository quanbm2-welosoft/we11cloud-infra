#! /usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-environments/staging.tfvars}"
RTO_LIMIT=300

echo "========================================"
echo "  DISASTER RECOVERY TEST"
echo "  Var file: $ENV_FILE"
echo "  RTO limit:  ${RTO_LIMIT}s (5 minutes)"
echo "========================================"
echo ""

# Safety check: chặn chạy trên production
if grep -q 'environment.*=.*"production"' "$ENV_FILE"; then
  echo "🚨 ABORTED: Không được chạy DR test trên production!"
  echo "   Dùng: bash disaster-recovery.sh environments/staging.tfvars"
  exit 1
fi

echo "⚠️  Script này sẽ DESTROY toàn bộ hạ tầng staging rồi dựng lại."
read -p "Gõ 'destroy' để tiếp tục: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "=== Phase 1: DESTROY ==="
terraform destroy -var-file="$ENV_FILE" -auto-approve
echo "✅ Destroy completed"
echo ""

echo "=== Phase 2: REBUILD (Đang đo thời gian...) ==="
START=$(date +%s)

terraform apply -var-file="$ENV_FILE" -auto-approve

END=$(date +%s)
DURATION=$((END - START))

echo ""
echo "================================="
echo "  RESULTS"
echo "================================="
echo "  Rebuild time:   ${DURATION}s"
echo "  RTO limit:      ${RTO_LIMIT}s"
echo ""

# Verify: kiểm tra resources đã tạo xong
echo "=== Phase 3: Verify ==="

FAIL=0

# Check VPC
if terraform state show module.network.linode_vpc.main > /dev/null 2>&1; then
  echo "  ✅ VPC created"
else 
  echo "  ❌ VPC missing"
  FAIL=1
fi

# Check Subnet
if terraform state show module.network.linode_vpc_subnet.app > /dev/null 2>&1; then 
  echo "  ✅ Subnet created"
else
  echo "  ❌ Subnet missing"
  FAIL=1
fi

# Check Firewall
if terraform state show module.compute.linode_firewall.api_gateway > /dev/null 2>&1; then
  echo "  ✅ Firewall created"
else
  echo "  ❌ Firewall missing"
  FAIL=1
fi

# Check bucket
if terraform state show module.storage.linode_object_storage_bucket.ingest_raw > /dev/null 2>&1; then
  echo "  ✅ Bucket ingest-raw created"
else
  echo "  ❌ Bucket ingest-raw missing"
  FAIL=1
fi

if terraform state show module.storage.linode_object_storage_bucket.delivey_hls > /dev/null 2>&1; then
  echo "  ✅ Bucket delivery-hls created"
else
  echo "  ❌ Bucket delivery-hls missing"
  FAIL=1
fi

# Check IAM Keys
if terraform state show module.storage.linode_object_storage_key.nestjs > /dev/null 2>&1; then
  echo "  ✅ NestJS IAM key created"
else
  echo "  ❌ NestJS IAM key missing"
  FAIL=1
fi

echo ""
echo "============================"

if [[ $DURATION -le $RTO_LIMIT && $FAIL -eq 0 ]]; then
  echo "  ✅ DR TEST PASSED"
  echo "  Rebuild: ${DURATION}s < ${RTO_LIMIT}s (RTO met)"
  echo "  All resources verified"
  echo "================================================="
  exit 0
elif [[ $FAIL -ne 0 ]]; then
  echo "  ❌ DR TEST FAILED — Missing resources"
  echo "================================================="
  exit 1
else 
  echo "  ❌ DR TEST FAILED — RTO exceeded"
  echo "  Rebuild: ${DURATION}s > ${RTO_LIMIT}s"
  echo "============================================"
  exit 1
fi