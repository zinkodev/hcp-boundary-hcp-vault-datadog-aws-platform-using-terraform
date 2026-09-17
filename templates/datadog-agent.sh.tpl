#!/bin/bash
set -euo pipefail

DD_API_KEY="${dd_api_key}" \
DD_SITE="${dd_site}" \
bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"

sleep 15

sed -i 's/^# logs_enabled: false/logs_enabled: true/' /etc/datadog-agent/datadog.yaml

if ! grep -q '^logs_enabled: true' /etc/datadog-agent/datadog.yaml; then
  echo "logs_enabled: true" >> /etc/datadog-agent/datadog.yaml
fi

mkdir -p /etc/datadog-agent/conf.d/journald.d

cat > /etc/datadog-agent/conf.d/journald.d/conf.yaml <<EOF
logs:
  - type: journald
    source: journald
    service: ${dd_service_name}
EOF

usermod -aG systemd-journal dd-agent
systemctl restart datadog-agent

sleep 10
systemctl is-active --quiet datadog-agent