output "jumphost_public_ip" {
  value = aws_instance.jumphost.public_ip
}

output "boundary_worker_private_ip" {
  value = aws_instance.boundary_worker.private_ip
}

output "target_private_ip" {
  value = aws_instance.target.private_ip
}

output "ssh_private_key_path" {
  value = local_file.private_key.filename
}

output "ssh_jumphost_command" {
  value = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.jumphost.public_ip}"
}

output "boundary_worker_id" {
  value = boundary_worker.self_managed.id
}

output "boundary_target_static_id" {
  value = boundary_target.ssh_target.id
}

output "boundary_target_vault_id" {
  value = boundary_target.ssh_target_vault.id
}

output "boundary_connect_vault_command" {
  value = "boundary connect ssh -target-id ${boundary_target.ssh_target_vault.id}"
}