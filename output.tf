

output "load_balancer_dns" {
  value       = aws_lb.recording_load_balancer.dns_name
  description = "The dns name of load balancer."

}



output "efs" {
  value       = aws_efs_file_system.recording-efs.dns_name
  description = "The efs info."

}


output "vpc_peering_id" {
  value       = aws_vpc_peering_connection.peer.id
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

    