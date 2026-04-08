#! /usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-config.sh"

TEST_PREFIX="test-$(date +%s)"

echo "--- Test 1: Authorized PUT (NestJS key -> ingest-raw) ---"

dd if=/dev/urandom of=/tmp/test-1mb.bin bs=1M count=1 2>/dev/null

if aws_nestjs s3api put-object \
  --bucket "$INGEST_BUCKET" \
  --key "$TEST_PREFIX/test-auth.bin" \
  --body /tmp/test-1mb.bin \
  --content-type "application/octet-stream" > /dev/null 2>&1; then 
  test_pass "NestJS key can write to ingest-raw"
else 
  test_fail "NestJS key should be able to write to ingest-raw"
fi

echo "--- Test 2: Unauthorized PUT (Worker key -> ingest-raw) ---"

if aws_worker s3api put-object \ 
  --bucket "$INGEST_BUCKET" \
  --key "$TEST_PREFIX/test-unauth.bin" \
  --body /tmp/test-1mb.bin \
  --content-type "application/octet-stream" > /dev/null 2>&1; then
  test_fail "Worker key should NOT be able to write to ingest-raw"
else 
  test_pass "Worker key correctly denied write to ingest-raw"
fi 

echo "--- Test 3: Public Read Deny (Anonymous GET -> ingest-raw) ---"

OBJECT_URL="$ENDPOINT/$INGEST_BUCKET/$TEST_PREFIX/test-auth.bin"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$OBJECT_URL")

if [[ "$HTTP_CODE" == "403" || "$HTTP_CODE" == "401" ]]; then 
  test_pass "Anonymous GET blocked (HTTP $HTTP_CODE)"
else 
  test_fail "Anonymous GET returned HTTP $HTTP_CODE (expected 403/401)"
fi

echo "--- Test 4: Tenant Isolation ---"

aws_nestjs s3api put-object \
  --bucket "$INGEST_BUCKET" \
  --key "$TEST_PREFIX/tenant_A/file-a.bin" \
  --body /tmp/test-1mb.bin > /dev/null 2>&1

aws_nestjs s3api put-object \
  --bucket "$INGEST_BUCKET" \
  --key "$TEST_PREFIX/tenant_B/file-b.bin" \
  --body /tmp/test-1mb.bin > /dev/null 2>&1

LIST_A=$(aws_nestjs s3api list-objects-v2 \
  --bucket "$INGEST_BUCKET" \
  --prefix "$TEST_PREFIX/tenant_A/" \
  --query "Contents[].Key" --output text) 

LIST_B=$(aws_nestjs s3api list-objects-v2 \
  --bucket "$INGEST_BUCKET" \
  --prefix "$TEST_PREFIX/tenant_B/" \
  --query "Contents[].Key" --output text)

if [[ "$LIST_A" == *"tenant_A"* && "$LIST_A" != *"tenant_B"* && \
      "$LIST_B" == *"tenant_B"* && "$LIST_B" != *"tenant_A"* ]]; then
  test_pass "Tenant prefix are isolated"
else 
  test_fail "Tenant data leaked across prefixes"
fi

echo "--- Cleanup ---"
aws_nestjs s3 rm "s3://$INGEST_BUCKET/$TEST_PREFIX/" --recursive > /dev/null 2>&1
rm -f /tmp/test-1mb.bin

test_summary