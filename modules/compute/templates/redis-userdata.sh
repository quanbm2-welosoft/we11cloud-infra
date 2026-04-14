#! /bin/bash
set -euo pipefail

apt-get update && apt-get install -y redis-server ufw

sed -i 's/^bind /# bind /' /etc/redis/redis.conf
echo "bind 10.0.1.30" >> /etc/redis/redis.conf
echo "requirepass ${redis_password}" >> /etc/redis/redis.conf

sed -i 's/^appendonly no/appendonly yes/' /etc/redis/redis.conf
echo "appendfsync everysec" >> /etc/redis/redis.conf

# Memory management - 75% RAM hệ thống
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
REDIS_MEM_MB=$(( TOTAL_MEM_KB * 75 / 100 / 1024 ))
echo "maxmemory ${REDIS_MEM_MB}mb" >> /etc/redis/redis.conf
echo "maxmemory-policy noeviction" >> /etc/redis/redis.conf

systemctl restart redis-server
systemctl enable redis-server

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow from 10.0.1.10 to any port 6379 proto tcp 
ufw allow from 10.0.1.20 to any port 6379 proto tcp
ufw --force enable

echo "Redis ready on 10.0.1.30"
