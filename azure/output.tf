output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway frontend."
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "appgw_fqdn" {
  description = "FQDN of the Application Gateway frontend public IP."
  value       = azurerm_public_ip.appgw_pip.fqdn
}
