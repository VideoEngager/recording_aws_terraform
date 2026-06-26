resource "random_string" "sa_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "sa" {
  name                     = "shareddata${random_string.sa_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "fs" {
  name               = "recordings-storage"
  storage_account_id = azurerm_storage_account.sa.id
  quota              = 50
}

resource "azurerm_storage_account_network_rules" "sa_rules" {
  storage_account_id         = azurerm_storage_account.sa.id
  default_action             = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.subnet.id]
  bypass                     = ["AzureServices", "Metrics", "Logging"]
  # Allow the public IP of the machine running Terraform!
  ip_rules = [chomp(data.http.my_public_ip.response_body)]

  depends_on = [
    azurerm_storage_share.fs
  ]
}

data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com"
}
