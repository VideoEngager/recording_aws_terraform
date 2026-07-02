data "azurerm_location" "location" {
  location = var.location
}

locals {
  location_availability_zones = distinct([
    for zm in data.azurerm_location.location.zone_mappings : zm.logical_zone
  ])
  location_supports_zones = length(local.location_availability_zones) > 1
  # location_supports_zones = false
  vm_availability_zones = local.location_supports_zones ? slice(sort(local.location_availability_zones), 0, 2) : []

  # Total instance count scales with the *_node_count variables. With 2 availability
  # zones available, each node_count unit adds one instance per zone (e.g. node_count=1 -> 2
  # instances, node_count=2 -> 4 instances, split evenly: odd instance numbers in zone A,
  # even instance numbers in zone B). Without zone support, node_count maps 1:1 to instances.
  kurento_instance_count    = local.location_supports_zones ? var.kurento_node_count * length(local.vm_availability_zones) : var.kurento_node_count
  processing_instance_count = local.location_supports_zones ? var.processing_node_count * length(local.vm_availability_zones) : var.processing_node_count
}
