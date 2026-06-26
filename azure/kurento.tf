# ---------------------------------------------------------------------------
# Dynamic "Latest" Image Lookup
# ---------------------------------------------------------------------------

data "azurerm_images" "kurento_images" {
  resource_group_name = var.image_rg_name
  tags_filter = {
    Version = var.image_tag_version
  }
}

locals {
  kurento_matching_image_names = [
    for img in data.azurerm_images.kurento_images.images : img.name
    if startswith(img.name, var.kurento_image_name_prefix)
  ]
  kurento_sorted_descending = reverse(sort(local.kurento_matching_image_names))
  kurento_latest_image_name = length(local.kurento_sorted_descending) > 0 ? local.kurento_sorted_descending[0] : ""
}

data "azurerm_image" "kurento_latest_image" {
  name                = local.kurento_latest_image_name
  resource_group_name = var.image_rg_name
}

# ---------------------------------------------------------------------------
#  Kurento Public IP Address
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "kurento_pip" {
  count               = local.vm_instance_count
  name                = "${var.resource_prefix}-kurento-pip-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.location_supports_zones ? [local.vm_availability_zones[count.index]] : null
}

resource "azurerm_network_interface" "kurento_nic" {
  count               = local.vm_instance_count
  name                = "${var.resource_prefix}-kurento-nic-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kurento_pip[count.index].id
  }
}

# ---------------------------------------------------------------------------
# Virtual Machine
# ---------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "kurento" {
  count               = local.vm_instance_count
  name                = "${var.resource_prefix}-kurento-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = "ubuntu"
  zone                = local.location_supports_zones ? local.vm_availability_zones[count.index] : null

  network_interface_ids = [
    azurerm_network_interface.kurento_nic[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Version = var.image_tag_version
  }

  admin_ssh_key {
    username   = "ubuntu"
    public_key = tls_private_key.throwaway.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = data.azurerm_image.kurento_latest_image.id

  user_data = base64encode(templatefile("${path.module}/kurento_startup.sh.tftpl", {
    storage_account_name = azurerm_storage_account.sa.name
    storage_account_key  = azurerm_storage_account.sa.primary_access_key
    file_share_name      = azurerm_storage_share.fs.name

    coturn_listener_port     = var.coturn_listener_port
    coturn_alt_listener_port = var.coturn_alt_listener_port
    internal_ip              = "127.0.0.1"
    turn_server_username     = random_string.random_username.result
    turn_server_password     = random_password.password.result
    turn_server_min_port     = var.min_port
    turn_server_max_port     = var.max_port
    turn_internal_ip         = "127.0.0.1"

    media_output_dir = var.media_input_mount_dir
  }))
}

moved {
  from = azurerm_public_ip.kurento_pip
  to   = azurerm_public_ip.kurento_pip[0]
}

moved {
  from = azurerm_network_interface.kurento_nic
  to   = azurerm_network_interface.kurento_nic[0]
}

moved {
  from = azurerm_linux_virtual_machine.kurento
  to   = azurerm_linux_virtual_machine.kurento[0]
}
