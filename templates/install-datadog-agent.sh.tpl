#!/bin/bash
set -euo pipefail

DD_API_KEY="${dd_api_key}" \
DD_SITE="${dd_site}" \
bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"

sleep 15

if grep -qE '^[[:space:]]*#?[[:space:]]*logs_enabled:' /etc/datadog-agent/datadog.yaml; then
  sed -i -E 's/^[[:space:]]*#?[[:space:]]*logs_enabled:.*/logs_enabled: true/' \
    /etc/datadog-agent/datadog.yaml
else
  echo "logs_enabled: true" >> /etc/datadog-agent/datadog.yaml
fi

mkdir -p /etc/datadog-agent/conf.d/journald.d

cat > /etc/datadog-agent/conf.d/journald.d/conf.yaml <<CONFIG
logs:
  - type: journald
    source: journald
    service: ${dd_service_name}
CONFIG

usermod -aG systemd-journal dd-agent
systemctl restart datadog-agent

sleep 10
systemctl is-active --quiet datadog-agent
