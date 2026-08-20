locals {
  location_supports_zones   = length(var.vm_availability_zones) > 1
  kurento_instance_count    = local.location_supports_zones ? var.kurento_node_count * length(var.vm_availability_zones) : var.kurento_node_count * 2
  processing_instance_count = local.location_supports_zones ? var.processing_node_count * length(var.vm_availability_zones) : var.processing_node_count * 2

  # One NAT Gateway + private subnet per availability zone so processing nodes
  # keep the same zone spread as when they sit on public IPs.
  nat_gw_count = var.use_nat_gw ? (local.location_supports_zones ? length(var.vm_availability_zones) : 1) : 0
}
  