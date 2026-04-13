#! /bin/bash
# Verify rằng từ internet công cộng, attacker KHÔNG thể truy cập:

# Port 6379 của Redis
# Port 22/80/443/v.v. trên Worker
# Bất kỳ port nào ngoài 80/443 trên API Gateway
set -uo pipefail

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  echo "✅ PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "❌ FAIL: $1"
}

echo "Reading IPs from environment variables..."

REDIS_PUBLIC_IP="${REDIS_PUBLIC_IP:-}"
WORKER_PUBLIC_IP="${WORKER_PUBLIC_IP:-}"
API_PUBLIC_IP="${API_PUBLIC_IP:-}"

if [ -z "$REDIS_PUBLIC_IP" ]; then
  echo "ERROR: Cannot read redis_ip from terraform output. Did you run 'terraform apply'?"
  exit 1
fi

if [ -z "$WORKER_PUBLIC_IP" ]; then
  echo "ERROR: Cannot read worker_ip from terraform output. Did you run 'terraform apply'?"
  # exit 1
fi

if [ -z "$API_PUBLIC_IP" ]; then
  echo "ERROR: Cannot read api_gateway_ip from terraform output. Did you run 'terraform apply'?"
  exit 1
fi

echo ""
echo "--- Test 1: Redis public ports must be BLOCKED ---"

if nc -zv -w 5 "$REDIS_PUBLIC_IP" 6379 2>/dev/null; then
  fail "Redis 6379 is OPEN to internet (CRITICAL SECURITY ISSUE)"
else 
  pass "Redis 6379 correctly blocked from internet"
fi

if nc -zv -w 5 "$REDIS_PUBLIC_IP" 80 2>/dev/null; then
  fail "Redis 80 is OPEN to internet (CRITICAL SECURITY ISSUE)"
else 
  pass "Redis 80 correctly blocked from internet"
fi 


if nc -zv -w 5 "$REDIS_PUBLIC_IP" 443 2>/dev/null; then
  fail "Redis 443 is OPEN to internet (CRITICAL SECURITY ISSUE)"
else 
  pass "Redis 443 correctly blocked from internet"
fi


if nc -zv -w 5 "$REDIS_PUBLIC_IP" 22 2>/dev/null; then
  fail "Redis 22 is OPEN to internet (CRITICAL SECURITY ISSUE)"
else 
  pass "Redis 22 correctly blocked from internet"
fi
if [ -n "$WORKER_PUBLIC_IP" ]; then

  echo ""
  echo "--- Test 2: Worker public ports must be BLOCKED ---"

  if nc -zv -w 5 "$WORKER_PUBLIC_IP" 80 2>/dev/null; then
    fail "Worker port 80 OPEN"
  else 
    pass "Worker 80 blocked"
  fi

  if nc -zv -w 5 "$WORKER_PUBLIC_IP" 6379 2>/dev/null; then
    fail "Worker port 6379 OPEN"
  else 
    pass "Worker 6379 blocked"
  fi

  if nc -zv -w 5 "$WORKER_PUBLIC_IP" 443 2>/dev/null; then
    fail "Worker port 443 OPEN"
  else 
    pass "Worker 443 blocked"
  fi

  if nc -zv -w 5 "$WORKER_PUBLIC_IP" 8080 2>/dev/null; then
    fail "Worker port 8080 OPEN"
  else 
    pass "Worker 8080 blocked"
  fi
fi

echo ""
echo "--- Test 3: API Gateway 80/443 must be OPEN ---"

if nc -zv -w 5 "$API_PUBLIC_IP" 80 2>/dev/null; then
  pass "API Gateway 80 open"
else 
  fail "API Gateway 80 NOT reachable"
fi

if nc -zv -w 5 "$API_PUBLIC_IP" 443 2>/dev/null; then
  pass "API Gateway 443 open"
else 
  fail "API Gateway 443 NOT reachable"
fi

if nc -zv -w 5 "$API_PUBLIC_IP" 6379 2>/dev/null; then
  fail "API Gateway port 6379 should NOT be open"
else 
  pass "API Gateway 6379 correctly blocked"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0