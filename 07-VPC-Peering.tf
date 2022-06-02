# Requester's side of the connection.
resource "aws_vpc_peering_connection" "peer" {
  count         = var.use_private_link ? 0 : 1
  vpc_id        = aws_vpc.recording_vpc.id
  peer_vpc_id   = var.csi_vpc_id 
  peer_owner_id = "376474804475"  
  peer_region   = var.csi_prod_deployment_region
  auto_accept   = false

  tags = {
    Name = "Customer Recording VPC Peering with main"
    Side = "Requester"
  }
}




# Create a route to Main VPC route table
resource "aws_route" "main_peer_access" {
  count                     = var.use_private_link ? 0 : 1
  route_table_id            = aws_route_table.recording_public.id
  destination_cidr_block    = var.controlling_vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[count.index].id

  depends_on = [
    aws_route_table.recording_public,
    aws_vpc_peering_connection.peer
  ]

}