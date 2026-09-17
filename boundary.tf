resource "boundary_worker" "self_managed" {
  scope_id    = "global"
  name        = "self-managed-worker-1"
  description = "Self-managed PKI worker in private subnet A"
}

# --- Static credential store (kept for the jumphost/legacy target) ---

resource "boundary_credential_store_static" "target_store" {
  name        = "target-cred-store"
  description = "Static credential store for Target EC2"
  scope_id    = var.boundary_project_scope_id
}

resource "boundary_credential_ssh_private_key" "target_ssh_key" {
  name                = "target"
  description         = "SSH Keypair for Target EC2"
  credential_store_id = boundary_credential_store_static.target_store.id
  username            = "ubuntu"
  private_key         = tls_private_key.ssh.private_key_pem
}

resource "boundary_target" "ssh_target" {
  name         = "Target-1"
  description  = "Target EC2 (static credential)"
  type         = "ssh"
  scope_id     = var.boundary_project_scope_id
  default_port = 22
  address      = aws_instance.target.private_ip

  session_max_seconds      = 28800
  session_connection_limit = -1

  egress_worker_filter = "\"private\" in \"/tags/type\""

  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.target_ssh_key.id
  ]
}

# --- Wait for the self-managed worker to fully register before creating the Vault credential store ---

resource "time_sleep" "wait_for_boundary_worker" {
  create_duration = "5m"

  depends_on = [
    aws_instance.boundary_worker,
    aws_route.to_hvn
  ]
}

# --- Vault credential store, points at PRIVATE Vault address (Step 13) ---

resource "boundary_credential_store_vault" "vault_store" {
  name          = "vault-ssh-signer"
  scope_id      = var.boundary_project_scope_id
  address       = var.vault_private_addr
  token         = var.vault_boundary_token
  namespace     = "admin"
  worker_filter = "\"private\" in \"/tags/type\""

  depends_on = [
    time_sleep.wait_for_boundary_worker
  ]
}

resource "boundary_credential_library_vault_ssh_certificate" "ssh_cert_lib" {
  name                = "ssh-cert-lib"
  credential_store_id = boundary_credential_store_vault.vault_store.id
  path                = "${var.ssh_ca_mount_path}/sign/${var.ssh_ca_role_name}"
  username            = "ubuntu"
  key_type            = "rsa"
  key_bits            = 2048
}

resource "boundary_target" "ssh_target_vault" {
  name         = "Target-1-Vault"
  description  = "Target EC2 (dynamic Vault-signed SSH cert)"
  type         = "ssh"
  scope_id     = var.boundary_project_scope_id
  default_port = 22
  address      = aws_instance.target.private_ip

  session_max_seconds      = 28800
  session_connection_limit = -1

  egress_worker_filter = "\"private\" in \"/tags/type\""

  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.ssh_cert_lib.id
  ]
}

resource "boundary_target" "boundary_worker_vault" {
  name         = "Self-Managed-Worker-Vault"
  description  = "Self-managed Boundary worker accessed using Vault-signed SSH certificates"
  type         = "ssh"
  scope_id     = var.boundary_project_scope_id
  default_port = 22
  address      = aws_instance.boundary_worker.private_ip

  session_max_seconds      = 28800
  session_connection_limit = -1

  egress_worker_filter = "\"private\" in \"/tags/type\""

  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.ssh_cert_lib.id
  ]

  depends_on = [
    null_resource.trust_vault_ca_worker
  ]
}
