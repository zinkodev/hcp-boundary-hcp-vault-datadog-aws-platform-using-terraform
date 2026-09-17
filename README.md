# HCP Boundary + HCP Vault SSH Certificate Lab

Terraform configuration for a private AWS environment that uses an HCP Boundary self-managed PKI worker and HCP Vault SSH certificates to provide controlled SSH access to a private EC2 target.

## What this deploys

- An AWS VPC with two public and two private subnets.
- An Internet Gateway, NAT Gateway, routing, and security groups.
- A public jumphost used only as the SSH hop for Terraform provisioning and administrative access.
- A private Boundary self-managed worker in private subnet A.
- A private SSH target in private subnet B.
- An AWS VPC peering connection and route between the AWS VPC and the HCP HVN.
- An HCP Boundary self-managed worker, static credential store/target, and Vault credential store/SSH-certificate target.
- An HCP Vault SSH secrets engine, certificate authority, role, and Boundary least-privilege policy.
- Installation of the Vault SSH CA public key on the target and Boundary worker as a trusted SSH user CA.
- Datadog Agent installation resources when a Datadog API key is supplied.

## Architecture

```text
Your workstation
   |
   +-- SSH / Terraform provisioning --> Jumphost (public subnet A)
                                           |
                                           +--> Boundary worker (private subnet A)
                                           |
                                           +--> SSH target (private subnet B)

HCP Boundary controller <--> Boundary worker
HCP Vault (private endpoint) <--> Boundary worker
HCP Vault SSH CA --> signed SSH certificate --> SSH target
AWS VPC <--> HCP HVN (AWS network peering)
```

The worker uses the `private` tag. The Boundary Vault credential store and targets filter for workers with that tag.

## Repository layout

| File | Purpose |
| --- | --- |
| `main.tf` | Terraform and provider versions; AWS VPC, subnets, NAT gateway, and routes |
| `security.tf` | Jumphost and private-instance security groups |
| `compute.tf` | Jumphost, Boundary worker, target instance, CA trust provisioning, and Datadog provisioning |
| `boundary.tf` | Boundary worker, credential stores, credential library, and targets |
| `vault.tf` | Vault SSH secrets engine, SSH CA/role, and Boundary policy |
| `vault-peering.tf` | HCP HVN ↔ AWS VPC network peering and routes |
| `keys.tf` | Terraform-generated AWS SSH key pair and local PEM file |
| `outputs.tf` | Instance information and Boundary connection outputs |
| `variables.tf` | Variable declarations and non-sensitive defaults |
| `terraform.tfvars` | Environment-specific, non-secret Terraform values |
| `templates/install-worker.sh.tpl` | Boundary PKI worker installation script |
| `templates/pki-worker.hcl.tpl` | Boundary worker configuration template |
| `templates/trust-vault-ca.sh.tpl` | Fetches and installs the Vault SSH CA public key |

## Prerequisites

Install and authenticate the following before running Terraform:

- Terraform `>= 1.3`
- AWS CLI configured with the AWS profile named in `terraform.tfvars`
- Vault CLI
- Boundary CLI
- `jq`
- `curl`
- An HCP Boundary cluster
- An HCP Vault cluster in an HCP HVN
- HCP credentials available in `HCP_CLIENT_ID` and `HCP_CLIENT_SECRET`
- A Datadog API key if using the Datadog resources

The AWS account running Terraform must be permitted to create the AWS resources in this configuration. The current Vault CLI login must be capable of creating the Vault SSH configuration, policy, and Boundary token.

## Important security notes

- **Never commit secrets**: do not put Vault tokens, Boundary passwords, or Datadog API keys in `terraform.tfvars`.
- Add `terraform.tfvars`, `*.tfstate*`, `.terraform/`, generated `*.pem` files, and Terraform plan files to `.gitignore`.
- Terraform generates an SSH private key and writes it to `<key_name>.pem`. The private key is also retained in Terraform state. Protect the state file and never commit it.
- The Vault namespace for this deployment is `admin`. All direct Vault API calls must include `X-Vault-Namespace: admin`.
- Use a Datadog **API key**, not an application key. The expected format is 32 lowercase hexadecimal characters.

Suggested `.gitignore` entries:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
*.pem
terraform.tfvars
crash.log
```

## Configure non-secret variables

Update `terraform.tfvars` with your environment-specific values. It contains values such as the AWS region/profile, CIDR ranges, your public IP CIDR, Boundary project scope ID, and Boundary login name.

Do not commit a real `terraform.tfvars`. Commit a sanitized `terraform.tfvars.example` instead.

## Deployment

Run the following from the repository root.

### 1. Configure endpoints and namespace

```bash
export AWS_PROFILE="master-programmatic-admin"
export VAULT_ADDR="https://vault-cluster-public-vault-719453c8.691c1b99.z1.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"
export BOUNDARY_ADDR="https://58d68045-53a9-461c-acf0-66de42ac8762.boundary.hashicorp.cloud"
export TF_VAR_datadog_site="datadoghq.com"
```

If your HCP cluster addresses or AWS profile differ, change the values to match your own environment.

### 2. Authenticate to Vault

Log in using the Vault authentication method configured for your environment:

```bash
vault login
```

Export the admin token used by Terraform. If your Vault CLI uses `~/.vault-token`:

```bash
export TF_VAR_vault_admin_token="$(< ~/.vault-token)"
```

If it uses `VAULT_TOKEN` instead:

```bash
export TF_VAR_vault_admin_token="${VAULT_TOKEN}"
```

Verify the exact Terraform variable has access:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "X-Vault-Namespace: admin" \
  -H "X-Vault-Token: ${TF_VAR_vault_admin_token}" \
  "${VAULT_ADDR}/v1/auth/token/lookup-self"
```

Expected result: `200`.

### 3. Create or refresh the Vault policy

The periodic token created in the next step depends on the `boundary-controller` policy. Create/update the policy first:

```bash
terraform init
terraform apply -target=vault_policy.boundary
```

### 4. Create the renewable Boundary Vault token

Boundary requires a renewable token. Create the token with the required periodic and orphan settings:

```bash
export TF_VAR_vault_boundary_token="$(
  vault token create \
    -namespace=admin \
    -policy=boundary-controller \
    -period=768h \
    -orphan \
    -format=json | jq -r '.auth.client_token'
)"
```

Check that it is renewable:

```bash
vault token lookup \
  -namespace=admin \
  -format=json "${TF_VAR_vault_boundary_token}" \
| jq '{renewable: .data.renewable, type: .data.type, policies: .data.policies, period: .data.period}'
```

Expected essentials:

```text
renewable: true
type: service
```

Confirm the token validates through the private Vault endpoint used by Boundary:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "X-Vault-Namespace: admin" \
  -H "X-Vault-Token: ${TF_VAR_vault_boundary_token}" \
  "https://vault-cluster-private-vault-719453c8.691c1b99.z1.hashicorp.cloud:8200/v1/auth/token/lookup-self"
```

Expected result: `200`.

### 5. Export remaining sensitive Terraform variables

```bash
read -rsp "Boundary admin password: " TF_VAR_boundary_admin_password
echo
export TF_VAR_boundary_admin_password

read -rsp "Datadog API key: " TF_VAR_datadog_api_key
echo
export TF_VAR_datadog_api_key
```

Validate the Datadog key format without exposing it:

```bash
if [[ "$TF_VAR_datadog_api_key" =~ ^[0-9a-f]{32}$ ]]; then
  echo "Datadog API key format: valid"
else
  echo "Datadog API key format: invalid; length=${#TF_VAR_datadog_api_key}"
fi
```

Validate it with Datadog:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -X GET "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: ${TF_VAR_datadog_api_key}"
```

Expected result: `200`.

### 6. Plan and apply

```bash
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The `time_sleep.wait_for_boundary_worker` resource intentionally waits five minutes after worker creation. This provides time for the self-managed worker to install, start, register, and become routable before Boundary creates the Vault credential store.

If an apply partially fails after resources are created, correct the reported issue and run `terraform apply` again. Do not destroy the full environment merely to retry a failed resource.

## Post-deployment checks

### Terraform outputs

```bash
terraform output
```

### Boundary worker

Use your configured Boundary authentication flow, then inspect the global workers:

```bash
boundary workers list -scope-id global
```

The self-managed worker must be active and match the `private` worker filter before the Vault credential store can be created or used.

### Vault credential store

```bash
terraform state show boundary_credential_store_vault.vault_store
```

### Datadog Agent

Connect through your configured SSH host alias for the worker, then check the agent:

```bash
ssh boundary_worker
sudo systemctl status datadog-agent --no-pager
sudo datadog-agent status
```

Validate the deployed API key without printing it:

```bash
sudo awk -F': ' '
/^api_key:/ {print "api_key_length=" length($2)}
/^site:/    {print "site=" $2}
' /etc/datadog-agent/datadog.yaml
```

A valid key should report `api_key_length=32`. You can validate it directly:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -X GET "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: $(sudo awk -F': ' '/^api_key:/{print $2}' /etc/datadog-agent/datadog.yaml)"
```

Expected result: `200`.

### Dynamic SSH through Boundary and Vault

Use the output command:

```bash
terraform output -raw boundary_connect_vault_command
```

Then run the printed `boundary connect ssh` command. It requests a Vault-signed SSH certificate through Boundary and connects to the Vault-backed target.

## Common issues

### Vault API returns `403`

Check that you are using a current token and include the namespace header:

```bash
-H "X-Vault-Namespace: admin"
```

Validate the exact token Terraform receives with the `auth/token/lookup-self` command shown above. A `403` means the supplied token is invalid, expired, or does not have required permissions.

### Boundary says the Vault token is not renewable

Recreate `TF_VAR_vault_boundary_token` as the periodic orphan token shown in step 4. Its token lookup must show `renewable: true`.

### Boundary says no workers are available or all are filtered

Check that the worker is active in Boundary and has the `private` tag. The Vault credential store uses:

```hcl
worker_filter = "\"private\" in \"/tags/type\""
```

### Remote CA trust provisioner returns `403`

Confirm `TF_VAR_vault_admin_token` can read the CA endpoint and that `templates/trust-vault-ca.sh.tpl` contains both headers:

```bash
-H "X-Vault-Token: ${vault_token}"
-H "X-Vault-Namespace: admin"
```

### Datadog Agent returns `403` / invalid API key

Check the key format and validate it with the Datadog `/api/v1/validate` endpoint. Ensure the API key has exactly 32 hexadecimal characters and that `TF_VAR_datadog_site` matches the Datadog site for the organization.

## Destroy

To remove resources managed by this Terraform state:

```bash
terraform destroy
```

Review the plan before confirming. Destruction removes the AWS infrastructure and Terraform-managed Boundary/Vault resources. A later `terraform apply` requires fresh, valid environment variables and a renewable Boundary Vault token.
