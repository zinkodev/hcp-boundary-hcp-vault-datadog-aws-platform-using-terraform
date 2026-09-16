# ---------------------------------------------------------------------------
# AMI — latest Ubuntu LTS, Canonical's official owner ID
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# EC2 instances
# ---------------------------------------------------------------------------

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
      cluster_id        = var.boundary_cluster_id
      activation_token  = boundary_worker.self_managed.controller_generated_activation_token
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
