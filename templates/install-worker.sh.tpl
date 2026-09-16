#!/bin/bash
set -e

mkdir -p /home/ubuntu/boundary
chown -R ubuntu:ubuntu /home/ubuntu/boundary

cat > /home/ubuntu/boundary/pki-worker.hcl <<'EOF'
${worker_config}
EOF

apt-get update && apt-get install -y jq unzip
wget -q "$(curl -fsSL 'https://api.releases.hashicorp.com/v1/releases/boundary/latest?license_class=enterprise' | jq -r '.builds[] | select(.arch=="amd64" and .os=="linux") | .url')" -O /tmp/boundary.zip
unzip -o /tmp/boundary.zip -d /usr/local/bin

cat > /etc/systemd/system/boundary.service <<'EOF'
[Unit]
Description=Boundary PKI Worker
After=network.target

[Service]
ExecStart=/usr/local/bin/boundary server -config=/home/ubuntu/boundary/pki-worker.hcl
Restart=on-failure
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable boundary
systemctl start boundary