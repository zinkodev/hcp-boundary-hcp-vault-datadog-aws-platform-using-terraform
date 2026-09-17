resource "vault_mount" "ssh_client_signer" {
  path = var.ssh_ca_mount_path
  type = "ssh"
}

resource "vault_ssh_secret_backend_ca" "this" {
  backend              = vault_mount.ssh_client_signer.path
  generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "boundary_client" {
  name                    = var.ssh_ca_role_name
  backend                 = vault_mount.ssh_client_signer.path
  key_type                = "ca"
  algorithm_signer        = "rsa-sha2-512"
  allow_user_certificates = true
  allowed_users           = "ubuntu"
  default_user            = "ubuntu"
  ttl                     = "30m0s"

  default_extensions = {
    permit-pty = ""
  }
}

# Least-privilege policy for Boundary's Vault token (Step 11)
resource "vault_policy" "boundary" {
  name = "boundary-controller"

  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
    path "auth/token/revoke-self" {
      capabilities = ["update"]
    }
    path "sys/leases/renew" {
      capabilities = ["update"]
    }
    path "sys/leases/revoke" {
      capabilities = ["update"]
    }
    path "sys/capabilities-self" {
      capabilities = ["update"]
    }
    path "${var.ssh_ca_mount_path}/sign/${var.ssh_ca_role_name}" {
      capabilities = ["create", "update"]
    }
  EOT
}