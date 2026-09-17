variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "Named profile from ~/.aws/config to use for authentication"
  type        = string
  default     = "master-programmatic-admin"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "public_subnet_a_cidr" {
  default = "172.16.1.0/24"
}

variable "public_subnet_b_cidr" {
  default = "172.16.2.0/24"
}

variable "private_subnet_a_cidr" {
  default = "172.16.101.0/24"
}

variable "private_subnet_b_cidr" {
  default = "172.16.102.0/24"
}

variable "az_a" {
  description = "Availability zone for the 'A' subnets"
  type        = string
  default     = "ap-southeast-1a"
}

variable "az_b" {
  description = "Availability zone for the 'B' subnets"
  type        = string
  default     = "ap-southeast-1b"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32), allowed to SSH into the jumphost. Get it from `curl ifconfig.me`."
  type        = string
}

variable "instance_type" {
  description = "Instance type for all three EC2 instances"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name for the AWS key pair"
  type        = string
  default     = "customer-profile-key"
}

variable "project_name" {
  description = "Prefix used to tag/name resources"
  type        = string
  default     = "customer-profile"
}


### For Boundary##

variable "boundary_cluster_id" {
  description = "HCP Boundary cluster ID"
  type        = string
  default     = "58d68045-53a9-461c-acf0-66de42ac8762"
}

variable "boundary_addr" {
  description = "HCP Boundary controller address"
  type        = string
  default     = "https://58d68045-53a9-461c-acf0-66de42ac8762.boundary.hashicorp.cloud"
}

variable "boundary_admin_login" {
  description = "HCP Boundary admin login name"
  type        = string
}

variable "boundary_admin_password" {
  description = "HCP Boundary admin password"
  type        = string
  sensitive   = true
}

##

variable "boundary_project_scope_id" {
  description = "Project scope ID in HCP Boundary (e.g. p_xxxxxxxx) where the target/credential store live"
  type        = string
}

### Vault ###

variable "vault_public_addr" {
  description = "Public Vault cluster URL, used ONLY for one-time CA setup (Steps 1-6)"
  type        = string
  default     = "https://vault-cluster-public-vault-719453c8.691c1b99.z1.hashicorp.cloud:8200"
}

variable "vault_private_addr" {
  description = "Private Vault cluster URL, used by Boundary's credential store at runtime"
  type        = string
  default     = "https://vault-cluster-private-vault-719453c8.691c1b99.z1.hashicorp.cloud:8200"
}

variable "vault_admin_token" {
  description = "Admin token used by Terraform to configure the SSH secrets engine (Steps 1-6)"
  type        = string
  sensitive   = true
}

variable "vault_boundary_token" {
  description = "Least-privilege Vault token for Boundary's credential store (Step 12)"
  type        = string
  sensitive   = true
}

variable "ssh_ca_role_name" {
  type    = string
  default = "boundary-client"
}

variable "ssh_ca_mount_path" {
  type    = string
  default = "ssh-client-signer"
}

### HVN ###

variable "hvn_id" {
  type    = string
  default = "hvn"
}

### Datadog ###

variable "datadog_api_key" {
  description = "Datadog Agent API key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site"
  type        = string
  default     = "datadoghq.com"
}