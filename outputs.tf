output "jumphost_public_ip" {
  description = "Public IP of the jumphost"
  value       = aws_instance.jumphost.public_ip
}

output "boundary_worker_private_ip" {
  description = "Private IP of the Boundary self-managed worker (Private Subnet A)"
  value       = aws_instance.boundary_worker.private_ip
}

output "target_private_ip" {
  description = "Private IP of the target instance (Private Subnet B)"
  value       = aws_instance.target.private_ip
}

output "ssh_private_key_path" {
  description = "Local path to the generated private key"
  value       = local_file.private_key.filename
}

output "ssh_jumphost_command" {
  description = "SSH straight into the jumphost"
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.jumphost.public_ip}"
}

output "ssh_worker_via_jumphost_command" {
  description = "SSH into the Boundary worker, hopping through the jumphost"
  value       = "ssh -i ${local_file.private_key.filename} -J ubuntu@${aws_instance.jumphost.public_ip} ubuntu@${aws_instance.boundary_worker.private_ip}"
}

output "ssh_target_via_jumphost_command" {
  description = "SSH into the target, hopping through the jumphost"
  value       = "ssh -i ${local_file.private_key.filename} -J ubuntu@${aws_instance.jumphost.public_ip} ubuntu@${aws_instance.target.private_ip}"
}

output "boundary_worker_id" {
  description = "ID of the registered Boundary self-managed worker"
  value       = boundary_worker.self_managed.id
}
###

output "boundary_target_id" {
  value = boundary_target.ssh_target.id
}

output "boundary_connect_command" {
  value = "boundary connect ssh -target-id ${boundary_target.ssh_target.id}"
}