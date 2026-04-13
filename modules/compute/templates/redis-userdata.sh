#! /bin/bash
set -euo pipefail

apt-get update && apt-get install -y redis-server ufw

sed -i 's/^bind /# bind /' /etc/redis/redis.conf
echo "bind 10.0.1.30" >> /etc/redis/redis.conf
echo "requirepass ${redis_password}" >> /etc/redis/redis.conf

systemctl restart redis-server
systemctl enable redis-server

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow from 10.0.1.10 to any port 6379 proto tcp 
ufw allow from 10.0.1.20 to any port 6379 proto tcp
ufw --force enable

echo "Redis ready on 10.0.1.30"
