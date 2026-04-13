#! /bin/bash
set -euo pipefail

apt-get update && apt-get upgrade -y

# Node.js 20 LTS 
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 
apt-get install -y nodejs

# pnpm
npm install -g pnpm

# Docker (cho CalmAV container)
curl -fsSL https://get.docker.com | bash
systemctl enable --now docker

echo "API Gateway ready. App port: ${app_port}"

apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 10.0.1.0/24 to any port 3310 proto tcp 
ufw --force enable 