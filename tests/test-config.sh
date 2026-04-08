#! /usr/bin/env bash
set -euo pipefail 

ENDPOINT="${ENDPOINT:-https://sg-sin-1.linodeobjects.com}"
REGION="${REGION:-sg-sin-2}"
INGEST_BUCKET="${INGEST_BUCKET:-we11-ingest-raw}"
DELIVERY_BUCKET="${DELIVERY_BUCKET:-we11-delivery-hls}"

for var in NESTJS_ACCESS_KEY NESTJS_SECRET_KEY WORKER_ACCESS_KEY WORKER_SECRET_KEY; do 
  if [[ -z "${!var:-}" ]]; then 
    echo "ERROR: $var is not set"
    exit 1
  fi
done 

aws_nestjs() {
  AWS_ACCESS_KEY_ID="$NESTJS_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$NESTJS_SECRET_KEY" \
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}

aws_worker() {
  AWS_ACCESS_KEY_ID="$WORKER_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$WORKER_SECRET_KEY" \
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@" 
}

PASS=0; FAIL=0

test_pass() {
  PASS=$((PASS + 1))
  echo " ✅ PASS: $1"
}

test_fail() {
  FAIL=$((FAIL + 1))
  echo " ❌ FAIL: $1"
}

test_summary() {
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed ==="
  [[ $FAIL -eq 0 ]]
}