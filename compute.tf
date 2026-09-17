# ----
# AMI — latest Ubuntu LTS, Canonical's official owner ID
# ----

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ----
# EC2 instances
# ----

# Public Subnet A — reachable from your IP, is the only hop into the VPC.
resource "aws_instance" "jumphost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.jumphost.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true

  tags = {
    Name = "Jumphost"
  }
}

# Private Subnet A — Boundary self-managed worker.
resource "aws_instance" "boundary_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = aws_key_pair.this.key_name

  user_data = templatefile("${path.module}/templates/install-worker.sh.tpl", {
    worker_config = templatefile("${path.module}/templates/pki-worker.hcl.tpl", {
      cluster_id       = var.boundary_cluster_id
      activation_token = boundary_worker.self_managed.controller_generated_activation_token
    })
  })

  tags = {
    Name = "Self Manage Worker 1"
  }

  depends_on = [boundary_worker.self_managed]
}

# Private Subnet B — target reached via the Boundary worker.
resource "aws_instance" "target" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = aws_key_pair.this.key_name

  tags = {
    Name = "Target"
  }
}

# ----
# Vault CA trust — target
# ----

resource "null_resource" "trust_vault_ca" {
  depends_on = [vault_mount.ssh_client_signer, vault_ssh_secret_backend_ca.this, aws_instance.target]

  connection {
    type                = "ssh"
    host                = aws_instance.target.private_ip
    user                = "ubuntu"
    private_key         = tls_private_key.ssh.private_key_pem
    bastion_host        = aws_instance.jumphost.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = tls_private_key.ssh.private_key_pem
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/trust-vault-ca.sh.tpl", {
      vault_addr  = var.vault_public_addr
      vault_token = var.vault_admin_token
      ca_mount    = var.ssh_ca_mount_path
    })
    destination = "/tmp/trust-vault-ca.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/trust-vault-ca.sh",
      "sudo /tmp/trust-vault-ca.sh"
    ]
  }
}

# ----
# Vault CA trust — worker
# ----

resource "null_resource" "trust_vault_ca_worker" {
  depends_on = [
    vault_mount.ssh_client_signer,
    vault_ssh_secret_backend_ca.this,
    aws_instance.boundary_worker
  ]

  connection {
    type                = "ssh"
    host                = aws_instance.boundary_worker.private_ip
    user                = "ubuntu"
    private_key         = tls_private_key.ssh.private_key_pem
    bastion_host        = aws_instance.jumphost.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = tls_private_key.ssh.private_key_pem
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/trust-vault-ca.sh.tpl", {
      vault_addr  = var.vault_public_addr
      vault_token = var.vault_admin_token
      ca_mount    = var.ssh_ca_mount_path
    })

    destination = "/tmp/trust-vault-ca.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/trust-vault-ca.sh",
      "sudo /tmp/trust-vault-ca.sh"
    ]
  }
}

# ----
# Datadog Agent — worker
# ----

resource "null_resource" "install_datadog_boundary_worker" {
  triggers = {
    instance_id = aws_instance.boundary_worker.id
  }

  depends_on = [
    aws_instance.boundary_worker
  ]

  connection {
    type                = "ssh"
    host                = aws_instance.boundary_worker.private_ip
    user                = "ubuntu"
    private_key         = tls_private_key.ssh.private_key_pem
    bastion_host        = aws_instance.jumphost.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = tls_private_key.ssh.private_key_pem
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/install-datadog-agent.sh.tpl", {
      dd_api_key      = var.datadog_api_key
      dd_site         = var.datadog_site
      dd_service_name = "boundary-self-managed-worker"
    })

    destination = "/tmp/install-datadog-agent.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-datadog-agent.sh",
      "sudo /tmp/install-datadog-agent.sh"
    ]
  }
}

# ----
# Datadog Agent — target
# ----

resource "null_resource" "install_datadog_target" {
  triggers = {
    instance_id = aws_instance.target.id
  }

  depends_on = [
    aws_instance.target
  ]

  connection {
    type                = "ssh"
    host                = aws_instance.target.private_ip
    user                = "ubuntu"
    private_key         = tls_private_key.ssh.private_key_pem
    bastion_host        = aws_instance.jumphost.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = tls_private_key.ssh.private_key_pem
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/install-datadog-agent.sh.tpl", {
      dd_api_key      = var.datadog_api_key
      dd_site         = var.datadog_site
      dd_service_name = "boundary-vault-ssh-target"
    })

    destination = "/tmp/install-datadog-agent.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-datadog-agent.sh",
      "sudo /tmp/install-datadog-agent.sh"
    ]
  }
}