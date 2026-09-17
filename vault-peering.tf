data "hcp_hvn" "this" {
  hvn_id = var.hvn_id
}

resource "hcp_aws_network_peering" "this" {
  hvn_id          = data.hcp_hvn.this.hvn_id
  peering_id      = "${var.project_name}-peering"
  peer_vpc_id     = aws_vpc.this.id
  peer_account_id = data.aws_caller_identity.current.account_id
  peer_vpc_region = var.aws_region
}

resource "hcp_hvn_route" "this" {
  hvn_link         = data.hcp_hvn.this.self_link
  hvn_route_id     = "${var.project_name}-hvn-route"
  destination_cidr = aws_vpc.this.cidr_block
  target_link      = hcp_aws_network_peering.this.self_link
}

resource "aws_vpc_peering_connection_accepter" "this" {
  vpc_peering_connection_id = hcp_aws_network_peering.this.provider_peering_id
  auto_accept                = true
}

resource "aws_route" "to_hvn" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = data.hcp_hvn.this.cidr_block
  vpc_peering_connection_id = hcp_aws_network_peering.this.provider_peering_id

  depends_on = [
    aws_vpc_peering_connection_accepter.this,
    hcp_hvn_route.this
  ]
}