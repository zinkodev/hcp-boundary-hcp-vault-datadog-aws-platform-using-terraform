terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.1"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.90"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    time = {
  source  = "hashicorp/time"
  version = "~> 0.12"
}
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "boundary" {
  addr                   = var.boundary_addr
  auth_method_login_name = var.boundary_admin_login
  auth_method_password   = var.boundary_admin_password
}


# HCP provider auth via HCP_CLIENT_ID / HCP_CLIENT_SECRET env vars
provider "hcp" {}

# Used only for Steps 1-6 (CA + role setup) — run against the PUBLIC Vault URL
provider "vault" {
  address = var.vault_public_addr
  token   = var.vault_admin_token
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC-${var.project_name}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_a_cidr
  availability_zone        = var.az_a
  map_public_ip_on_launch  = true

  tags = {
    Name = "Public Subnet A"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_b_cidr
  availability_zone        = var.az_b
  map_public_ip_on_launch  = true

  tags = {
    Name = "Public Subnet B"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = var.az_a

  tags = {
    Name = "Private Subnet A"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = var.az_b

  tags = {
    Name = "Private Subnet B"
  }
}

# ---------------------------------------------------------------------------
# NAT Gateway (lives in Public Subnet A, per the diagram)
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "NAT gateway"
  }

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
