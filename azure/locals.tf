data "azurerm_location" "location" {
  location = var.location
}

locals {
  location_availability_zones = distinct([
    for zm in data.azurerm_location.location.zone_mappings : zm.logical_zone
  ])
  location_supports_zones = length(local.location_availability_zones) > 1
  # location_supports_zones = false
  vm_instance_count       = local.location_supports_zones ? 2 : 1
  vm_availability_zones   = local.location_supports_zones ? slice(sort(local.location_availability_zones), 0, 2) : []
}
