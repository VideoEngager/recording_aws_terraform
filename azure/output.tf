output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway frontend."
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "nat_gateway_public_ip" {
  description = "Public IP address(es) of the processing NAT Gateway(s). One per availability zone when zones are enabled; empty when use_nat_gw is false. Use these addresses to allowlist processing egress."
  value       = azurerm_public_ip.nat_pip[*].ip_address
}

output "kurento_public_ips" {
  description = "Public IP addresses of the kurento VMs."
  value       = azurerm_public_ip.kurento_pip[*].ip_address
}

output "processing_public_ips" {
  description = "Public IP addresses of the processing VMs. Empty when use_nat_gw is true (processing nodes have private IPs only)."
  value       = azurerm_public_ip.processing_pip[*].ip_address
}

output "appgw_fqdn" {
  description = "FQDN of the Application Gateway frontend public IP."
  value       = azurerm_public_ip.appgw_pip.fqdn
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace collecting instance logs."
  value       = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace collecting instance logs."
  value       = azurerm_log_analytics_workspace.law.name
}

output "kurento_log_table_name" {
  description = "Log Analytics custom table holding kurento + coturn logs (query with KQL)."
  value       = local.kurento_table_name
}

output "processing_log_table_name" {
  description = "Log Analytics custom table holding recsvc/archiver/verint/transcribe logs (query with KQL)."
  value       = local.recsvc_table_name
}
