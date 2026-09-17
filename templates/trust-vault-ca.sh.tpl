#!/bin/bash
set -e

curl -s "${vault_addr}/v1/${ca_mount}/config/ca" \
  -H "X-Vault-Token: ${vault_token}" | jq -r '.data.public_key' \
  > /etc/ssh/trusted-user-ca-keys.pem

if ! grep -q "TrustedUserCAKeys" /etc/ssh/sshd_config; then
  echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config
fi

sudo systemctl restart ssh