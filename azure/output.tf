output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway frontend."
  value       = azurerm_public_ip.appgw_pip.ip_address
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
