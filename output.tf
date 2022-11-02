

output "load_balancer_dns" {
  value       = aws_lb.recording_load_balancer.dns_name
  description = "The dns name of load balancer."

}



output "efs" {
  value       = aws_efs_file_system.recording-efs.dns_name
  description = "The efs info."

}


output "vpc_peering_id" {
  value       = aws_vpc_peering_connection.peer.*.id
  description = "VPC Peering Connection Id"
}

output "efs_mount_ip_address_subnet1" {
  value       = local.efs_mount_ip_address_subnet1
  description = "The efs mount point IP address info for subnet 1."

}

output "efs_mount_ip_address_subnet2" {
  value       = local.efs_mount_ip_address_subnet2
  description = "The efs mount point IP address info for subnet 2."

}

output "private_link_service_name" {
  value       = aws_vpc_endpoint_service.private_link_service.*.service_name
  description = "Private Link Service Name"
}

output "elastic_ips" {
  value       = aws_eip.eip.*.public_ip
  description = "Elastic IP adresses"
}

output "play_app_gateway_url" {
  value       = aws_apigatewayv2_api.play_gateway.*.api_endpoint
  description = "The dns name of play service load balancer."
}