#!/bin/bash
set -euo pipefail

CA_FILE="/etc/ssh/trusted-user-ca-keys.pem"
TEMP_CA_FILE="$(mktemp)"

trap 'rm -f "$TEMP_CA_FILE"' EXIT

curl --fail --silent --show-error \
  "${vault_addr}/v1/${ca_mount}/config/ca" \
  -H "X-Vault-Token: ${vault_token}" \
  -H "X-Vault-Namespace: admin" \
  | jq -er '.data.public_key' > "$TEMP_CA_FILE"

test -s "$TEMP_CA_FILE"

install -o root -g root -m 0644 "$TEMP_CA_FILE" "$CA_FILE"

if ! grep -qE '^[[:space:]]*TrustedUserCAKeys[[:space:]]+' /etc/ssh/sshd_config; then
  echo "TrustedUserCAKeys $CA_FILE" >> /etc/ssh/sshd_config
fi

sshd -t
systemctl restart ssh