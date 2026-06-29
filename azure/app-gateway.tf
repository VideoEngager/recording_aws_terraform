# ---------------------------------------------------------------------------
# Application Gateway (L7) - mirrors AWS ALB listeners for kurento & processing
# ---------------------------------------------------------------------------

locals {
  appgw_services = concat(
    [
      {
        key        = "kurento"
        port       = var.kurento_listen_port
        pool       = "kurento"
        probe_path = "/"
        match      = ["426"]
      },
      {
        key        = "processing"
        port       = var.recording_service_listen_port
        pool       = "processing"
        probe_path = "/health"
        match      = ["200"]
      },
    ],
    var.use_archiver_service ? [{
      key        = "archiver"
      port       = var.archiver_service_listen_port
      pool       = "processing"
      probe_path = "/health"
      match      = ["200"]
    }] : [],
    var.use_verint_connector_service ? [{
      key        = "verint"
      port       = var.verint_connector_listen_port
      pool       = "processing"
      probe_path = "/health"
      match      = ["200"]
    }] : [],
    var.use_aws_transcribe_service ? [{
      key        = "transcribe"
      port       = var.aws_transcribe_listen_port
      pool       = "processing"
      probe_path = "/health"
      match      = ["200"]
    }] : [],
  )

  appgw_services_map = {
    for idx, svc in local.appgw_services : svc.key => merge(svc, {
      priority = 100 + idx * 10
    })
  }

  appgw_inbound_ports = distinct(concat(
    [var.kurento_listen_port, var.recording_service_listen_port],
    var.use_archiver_service ? [var.archiver_service_listen_port] : [],
    var.use_verint_connector_service ? [var.verint_connector_listen_port] : [],
    var.use_aws_transcribe_service ? [var.aws_transcribe_listen_port] : [],
  ))
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "${var.resource_prefix}-appgw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.location_supports_zones ? local.vm_availability_zones : null
}

resource "azurerm_application_gateway" "recording" {
  name                = "${var.resource_prefix}-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  zones               = local.location_supports_zones ? local.vm_availability_zones : null

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = var.appgw_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name         = "kurento"
    ip_addresses = [for nic in azurerm_network_interface.kurento_nic : nic.private_ip_address]
  }

  backend_address_pool {
    name         = "processing"
    ip_addresses = [for nic in azurerm_network_interface.processing_nic : nic.private_ip_address]
  }

  dynamic "frontend_port" {
    for_each = local.appgw_services_map
    content {
      name = "${frontend_port.value.key}-port"
      port = frontend_port.value.port
    }
  }

  dynamic "probe" {
    for_each = local.appgw_services_map
    content {
      name                                      = "${probe.value.key}-probe"
      protocol                                  = "Http"
      path                                      = probe.value.probe_path
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = true

      match {
        status_code = probe.value.match
      }
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.appgw_services_map
    content {
      name                                = "${backend_http_settings.value.key}-settings"
      cookie_based_affinity               = "Enabled"
      port                                = backend_http_settings.value.port
      protocol                            = "Http"
      request_timeout                     = 900
      probe_name                          = "${backend_http_settings.value.key}-probe"
      pick_host_name_from_backend_address = true
    }
  }

  dynamic "http_listener" {
    for_each = local.appgw_services_map
    content {
      name                           = "${http_listener.value.key}-listener"
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name             = "${http_listener.value.key}-port"
      protocol                       = "Http"
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.appgw_services_map
    content {
      name                       = "${request_routing_rule.value.key}-rule"
      rule_type                  = "Basic"
      http_listener_name         = "${request_routing_rule.value.key}-listener"
      backend_address_pool_name  = request_routing_rule.value.pool
      backend_http_settings_name = "${request_routing_rule.value.key}-settings"
      priority                   = request_routing_rule.value.priority
    }
  }
}
