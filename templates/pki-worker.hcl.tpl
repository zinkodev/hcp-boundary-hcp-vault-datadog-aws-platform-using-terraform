disable_mlock = true

hcp_boundary_cluster_id = "${cluster_id}"

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

worker {
  auth_storage_path                     = "/home/ubuntu/boundary/worker1"
  controller_generated_activation_token = "${activation_token}"
  
  tags {
    type = ["private", "worker1"]
  }
}