resource "azurerm_network_security_group" "kurento_nsg" {
  name                = "${var.resource_prefix}-kurento-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-TCP-22-Specific-IP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-TCP-${var.kurento_listen_port}-Specific-IP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.kurento_listen_port
    source_address_prefixes    = azurerm_subnet.appgw_subnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-UDP-HighPorts-Internet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "55000-65535"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "kurento_nsg_assoc" {
  count                     = local.vm_instance_count
  network_interface_id      = azurerm_network_interface.kurento_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.kurento_nsg.id
}

moved {
  from = azurerm_network_interface_security_group_association.kurento_nsg_assoc
  to   = azurerm_network_interface_security_group_association.kurento_nsg_assoc[0]
}

resource "azurerm_network_security_group" "processing_nsg" {
  name                = "${var.resource_prefix}-processing-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-TCP-22-Specific-IP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-TCP-${var.recording_service_listen_port}-Specific-IP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.recording_service_listen_port
    source_address_prefixes    = azurerm_subnet.appgw_subnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-TCP-${var.archiver_service_listen_port}-Specific-IP"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.archiver_service_listen_port
    source_address_prefixes    = azurerm_subnet.appgw_subnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-TCP-${var.verint_connector_listen_port}-Specific-IP"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.verint_connector_listen_port
    source_address_prefixes    = azurerm_subnet.appgw_subnet.address_prefixes
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = var.use_aws_transcribe_service ? [1] : []
    content {
      name                       = "Allow-TCP-${var.aws_transcribe_listen_port}-Specific-IP"
      priority                   = 104
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = var.aws_transcribe_listen_port
      source_address_prefixes    = azurerm_subnet.appgw_subnet.address_prefixes
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_network_interface_security_group_association" "processing_nsg_assoc" {
  count                     = local.vm_instance_count
  network_interface_id      = azurerm_network_interface.processing_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.processing_nsg.id
}

moved {
  from = azurerm_network_interface_security_group_association.processing_nsg_assoc
  to   = azurerm_network_interface_security_group_association.processing_nsg_assoc[0]
}

resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "${var.resource_prefix}-appgw-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = { for idx, port in local.appgw_inbound_ports : tostring(port) => {
      port     = port
      priority = 200 + idx
    } }
    content {
      name                       = "Allow-TCP-${security_rule.value.port}-Allowed"
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value.port)
      source_address_prefixes    = var.appgw_allowed_cidrs
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}
