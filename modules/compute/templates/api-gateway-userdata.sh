#! /bin/bash
set -euo pipefail

apt-get update & apt-get upgrade -y

# Node.js 20 LTS 
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 
apt-get install -y nodejs

# pnpm
npm install -g pnpm

# Docker (cho CalmAv container)
curl -fsSL https://get.docker.com | bash
systemctl enable --now docker

echo "API Gateway ready. App port: ${app_port}"