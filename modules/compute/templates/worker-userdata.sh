#! /bin/bash
set -euo pipefail

apt-get update && apt-get upgrade -y 

# Go 1.22 
wget -q https://go.dev/dl/go1.22.4.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz
rm go1.22.4.linux-amd64.tar.gz 
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh

# FFmpeg 
apt-get install -y ffmpeg

# Docker 
curl -fsSL https://get.docker.com | bash
systemctl enable --now docker

echo "Worker ready" 

apt-get install -y ufw
ufw default deny incoming 
ufw default allow outgoing
ufw allow 22/tcp
ufw allow from 10.0.1.10 to any port 8080 proto tcp
ufw --force enable