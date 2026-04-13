#! /bin/bash 

set -uo pipefail

REDIS_PRIVATE_IP="10.0.1.30"
WORKER_PRIVATE_IP="10.0.1.20"
REDIS_PORT=6379 

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

echo ""
echo "--- Test 1: Ping private IPs ---"

if ping -c 3 -W 2 "$REDIS_PRIVATE_IP" > /dev/null 2>&1; then
  pass "Ping Redis ($REDIS_PRIVATE_IP) successful"
else
  fail "Cannot ping Redis at $REDIS_PRIVATE_IP"
fi

if ping -c 3 -W 2 "$WORKER_PRIVATE_IP" > /dev/null 2>&1; then
  pass "Ping Worker ($WORKER_PRIVATE_IP) successful"
else 
  fail "Cannot ping Worker at $WORKER_PRIVATE_IP"
fi

echo ""
echo "--- Test 2: TCP connectivity ---"

if nc -zv -w 3 "$REDIS_PRIVATE_IP" "$REDIS_PORT" 2>/dev/null; then
  pass "Redis port $REDIS_PORT reachable from gateway"
else 
  fail "Cannot connect to Redis $REDIS_PRIVATE_IP:$REDIS_PORT"
fi

if nc -zv -w 3 "$WORKER_PRIVATE_IP" 22 2>/dev/null; then
  pass "Worker SSH port reachable from gateway (VPC internal)"
else 
  fail "Cannot connect to Worker $WORKER_PRIVATE_IP:22"
fi

echo ""
echo "--- Test 3: UFW firewall status ---"

if sudo ufw status | grep -q "Status: active"; then
  pass "UFW is active"
else 
  fail "UFW is NOT active"
fi

if sudo ufw status | grep -q "22/tcp.*ALLOW"; then
  pass "UFW has SSH (22) allow rule"
else 
  fail "UFW missing SSH allow rule"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0