#! /bin/bash
set -uo pipefail

PASS=0
FAIL=0
MIN_GBPS=1
DURATION=60
REDIS_PRIVATE_IP="10.0.1.30"

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
API_PUBLIC_IP="${API_PUBLIC_IP:-}"

if [ -z "$API_PUBLIC_IP" ]; then
  echo "ERROR: Cannot read api_gateway_ip. Did you run 'terraform apply'?"
  exit 1
fi

if [ -z "$REDIS_PUBLIC_IP" ]; then
  echo "ERROR: Cannot read redis_ip. Did you run 'terraform apply'?"
  exit 1
fi
echo ""
echo "--- Setup: Installing iperf3 ---"

# 2 dòng SSH chạy song song → cài đồng thời trên 2 máy, tiết kiệm thời gian
# -o StrictHostKeyChecking=no = không hỏi "Are you sure you want to connect?" lần đầu SSH. Trong production nên dùng known_hosts, nhưng test thì OK.
# & cuối dòng = chạy background, không đợi xong mới chạy dòng tiếp theo
# > /dev/null 2>&1 = giấu output apt-get (rất dài, rối)
ssh -o StrictHostKeyChecking=no root@"$API_PUBLIC_IP" "apt-get install -y iperf3" > /dev/null 2>&1 &
ssh -o StrictHostKeyChecking=no root@"$REDIS_PUBLIC_IP" "apt-get install -y iperf3" > /dev/null 2>&1 &
wait # wait = đợi tất cả background jobs xong

echo "iperf3 installed on both servers"

# --- Mở port 5201 tạm trên Redis để iperf3 nhận traffic từ gateway ---
ssh root@"$REDIS_PUBLIC_IP" "ufw allow from 10.0.1.10 to any port 5201" > /dev/null 2>&1

echo "Starting iperf3 server on Redis..."

# -s = server mode (lắng nghe kết nối)
# -D = daemon (chạy nền, SSH return ngay)
# --pidfile /tmp/iperf3.pid = ghi process ID ra file, để kill chính xác ở bước cleanup
# đợi 2 giây cho server khởi động xong trước khi client connect
ssh root@"$REDIS_PUBLIC_IP" "iperf3 -s -D --pidfile /tmp/iperf3.pid"
sleep 2 

echo "Running bandwidth test for ${DURATION}s..."
RESULT=$(ssh root@"$API_PUBLIC_IP" "iperf3 -c $REDIS_PRIVATE_IP -t $DURATION -J")

echo ""
echo "--- Test: Bandwidth ---"

BITS_PER_SEC=$(echo "$RESULT" | jq '.end.sum_received.bits_per_second')
RETRANSMITS=$(echo "$RESULT" | jq '.end.sum_sent.retransmits')
GBPS=$(echo "scale=2; $BITS_PER_SEC / 1000000000" | bc)

echo "Measured: ${GBPS} Gbps, Retransmits: ${RETRANSMITS}"

if (( $(echo "$GBPS < $MIN_GBPS" | bc -l) )); then
  fail "Bandwidth ${GBPS} Gbps < ${MIN_GBPS} Gbps minimum"
else 
  pass "Bandwidth ${GBPS} Gbps meets minimum ${MIN_GBPS} Gbps"
fi

if [ "$RETRANSMITS" -gt 0 ] 2>/dev/null; then
  fail "Packet loss detected: $RETRANSMITS retransmits"
else 
  pass "Zero retransmits (no packet loss)"
fi

echo ""
echo "--- Cleanup ---"

ssh root@"$REDIS_PUBLIC_IP" "kill \$(cat /tmp/iperf3.pid) 2>/dev/null; rm -f /tmp/iperf3.pid"
ssh root@"$REDIS_PUBLIC_IP" "ufw delete allow from 10.0.1.10 to any port 5201" 2>/dev/null

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0