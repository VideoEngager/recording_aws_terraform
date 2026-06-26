# ---------------------------------------------------------------------------
# Dynamic "Latest" Image Lookup
# ---------------------------------------------------------------------------

data "azurerm_images" "processing_images" {
  resource_group_name = var.image_rg_name
  tags_filter = {
    Version = var.image_tag_version
  }
}

locals {
  processing_matching_image_names = [
    for img in data.azurerm_images.processing_images.images : img.name
    if startswith(img.name, var.processing_image_name_prefix)
  ]
  processing_sorted_descending = reverse(sort(local.processing_matching_image_names))
  processing_latest_image_name = length(local.processing_sorted_descending) > 0 ? local.processing_sorted_descending[0] : ""
}

data "azurerm_image" "processing_latest_image" {
  name                = local.processing_latest_image_name
  resource_group_name = var.image_rg_name
}

# ---------------------------------------------------------------------------
#  Processing Public IP Address
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "processing_pip" {
  count               = local.vm_instance_count
  name                = "${var.resource_prefix}-processing-pip-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = local.location_supports_zones ? [local.vm_availability_zones[count.index]] : null
}

resource "azurerm_network_interface" "processing_nic" {
  count               = local.vm_instance_count
  name                = "${var.resource_prefix}-processing-nic-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.processing_pip[count.index].id
  }
}

# ---------------------------------------------------------------------------
# Virtual Machine
# ---------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "processing" {
  count               = local.vm_instance_count
  name                = "${var.resource_prefix}-processing-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = "ubuntu"
  zone                = local.location_supports_zones ? local.vm_availability_zones[count.index] : null

  network_interface_ids = [
    azurerm_network_interface.processing_nic[count.index].id,
  ]

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

  source_image_id = data.azurerm_image.processing_latest_image.id

  user_data = base64encode(templatefile("${path.module}/processing_startup.sh.tftpl", {
    storage_account_name = azurerm_storage_account.sa.name
    storage_account_key  = azurerm_storage_account.sa.primary_access_key
    file_share_name      = azurerm_storage_share.fs.name

    recsvc_listen_port        = var.recording_service_listen_port
    mixer_tool                = var.mixer_tool
    genesys_webdav_server_url = var.genesys_webdav_server_url
    genesys_username          = var.genesys_username
    genesys_password          = var.genesys_password
    reporter_url              = "${var.reporter_host}${var.reporter_path}"

    media_output_dir     = var.media_output_mount_dir
    media_input_dir      = var.media_input_mount_dir
    media_mixer_dir      = var.media_mixer_dir
    media_file_ready_dir = var.media_file_ready_dir

    use_archiver         = var.use_archiver_service
    archiver_listen_port = var.archiver_service_listen_port
    archiver_base_url    = var.reporter_host

    use_verint_connector         = var.use_verint_connector_service
    verint_connector_listen_port = var.verint_connector_listen_port
    verint_connector_base_url    = var.reporter_host

    use_aws_transcribe         = var.use_aws_transcribe_service
    aws_transcribe_listen_port = var.aws_transcribe_listen_port
    aws_transcribe_base_url    = var.reporter_host

  }))
}

moved {
  from = azurerm_public_ip.processing_pip
  to   = azurerm_public_ip.processing_pip[0]
}

moved {
  from = azurerm_network_interface.processing_nic
  to   = azurerm_network_interface.processing_nic[0]
}

moved {
  from = azurerm_linux_virtual_machine.processing
  to   = azurerm_linux_virtual_machine.processing[0]
}
