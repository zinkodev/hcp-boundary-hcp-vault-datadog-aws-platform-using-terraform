resource "boundary_worker" "self_managed" {
  scope_id    = "global"
  name        = "self-managed-worker-1"
  description = "Self-managed PKI worker in private subnet A"
}

# ----
# Static Credential Store & SSH Keypair Credential
# ----

resource "boundary_credential_store_static" "target_store" {
  name        = "target-cred-store"
  description = "Static credential store for Target EC2"
  scope_id    = var.boundary_project_scope_id
}

###
resource "boundary_credential_ssh_private_key" "target_ssh_key" {
  name                = "target"
  description         = "SSH Keypair for Target EC2"
  credential_store_id = boundary_credential_store_static.target_store.id
  username            = "ubuntu"
  private_key         = tls_private_key.ssh.private_key_pem
}

# ----
# Boundary SSH Target
# ----

resource "boundary_target" "ssh_target" {
  name         = "Target-1"
  description  = "Target EC2 in Private Subnet B"
  type         = "ssh"
  scope_id     = var.boundary_project_scope_id
  default_port = 22
  address      = aws_instance.target.private_ip

  session_max_seconds      = 28800
  session_connection_limit = -1

  egress_worker_filter = "\"worker1\" in \"/tags/type\""

  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.target_ssh_key.id
  ]
}