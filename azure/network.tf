resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  # Enable the Storage Service Endpoint to lock down storage account
  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ---------------------------------------------------------------------------
# Processing private subnets + NAT Gateways (when use_nat_gw = true)
# One zonal NAT Gateway + private subnet per availability zone so processing
# VMs keep multi-AZ placement. Each NAT public IP is the only public address
# for that zone; processing NICs stay private-only.
# ---------------------------------------------------------------------------

resource "azurerm_subnet" "processing_private" {
  count                = local.nat_gw_count
  name                 = local.location_supports_zones ? "processing-private-${var.vm_availability_zones[count.index]}" : "processing-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [cidrsubnet(one(azurerm_virtual_network.vnet.address_space), 8, 3 + count.index)]
  service_endpoints    = ["Microsoft.Storage"]

  # Outbound goes through the NAT Gateway, not Azure default outbound access.
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "nat_pip" {
  count               = local.nat_gw_count
  name                = local.location_supports_zones ? "${var.resource_prefix}-nat-pip-${var.vm_availability_zones[count.index]}" : "${var.resource_prefix}-nat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.location_supports_zones ? [var.vm_availability_zones[count.index]] : null
}

resource "azurerm_nat_gateway" "processing" {
  count                   = local.nat_gw_count
  name                    = local.location_supports_zones ? "${var.resource_prefix}-processing-nat-${var.vm_availability_zones[count.index]}" : "${var.resource_prefix}-processing-nat"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = local.location_supports_zones ? [var.vm_availability_zones[count.index]] : null
}

resource "azurerm_nat_gateway_public_ip_association" "processing" {
  count                = local.nat_gw_count
  nat_gateway_id       = azurerm_nat_gateway.processing[count.index].id
  public_ip_address_id = azurerm_public_ip.nat_pip[count.index].id
}

resource "azurerm_subnet_nat_gateway_association" "processing_private" {
  count          = local.nat_gw_count
  subnet_id      = azurerm_subnet.processing_private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.processing[count.index].id
}

