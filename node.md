export TF_VAR_boundary_admin_login="zinkothu"
export TF_VAR_boundary_admin_password="<SET_VIA_ENV_VAR>"






cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set my_ip_cidr to `curl ifconfig.me`/32, pick your AZs/region

terraform init
terraform plan
terraform apply


terraform output ssh_to_jumphost
terraform output ssh_to_self_manage_worker_1_via_jumphost
terraform output ssh_to_target_via_jumphost



export HCP_CLIENT_ID=befbf83f2ed00f0f7c1e34d999425be5
export HCP_CLIENT_SECRET=470a3752a1c00fd5b07f0330f7f9b0144a653391b30f221142f22424234e50b4
export TF_VAR_boundary_admin_password=gengleG3!@#$1234
export VAULT_NAMESPACE=admin
export TF_VAR_vault_admin_token=<SET_VIA_ENV_VAR>
export TF_VAR_vault_boundary_token=<SET_VIA_ENV_VAR>


export VAULT_ADDR="https://vault-cluster-public-vault-719453c8.691c1b99.z1.hashicorp.cloud:8200"
vault login $TF_VAR_vault_admin_token (against vault_public_addr).
vault policy write boundary-controller boundary-policy.hcl
vault token create -policy=boundary-controller -period=768h → grab the token.
export TF_VAR_vault_boundary_token=<that token>

export TF_VAR_datadog_api_key="your_rotated_datadog_api_key"

then run terraform command




curl -s "${vault_addr}/v1/${ca_mount}/config/ca" \
  -H "X-Vault-Token: ${vault_token}" \
  -H "X-Vault-Namespace: admin" | jq -r '.data.public_key' \
  > /etc/ssh/trusted-user-ca-keys.pem






cd ~/pov-boundary/tf-boundary-vault

read -rsp "Datadog API key: " TF_VAR_datadog_api_key
echo
export TF_VAR_datadog_api_key
export TF_VAR_datadog_site="datadoghq.com"

if [[ "$TF_VAR_datadog_api_key" =~ ^[0-9a-f]{32}$ ]]; then
  echo "Datadog API key format: valid"
else
  echo "Datadog API key format: invalid"
  echo "length=${#TF_VAR_datadog_api_key}"
fi