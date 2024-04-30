locals {
  use_turn_nodes               = var.use_separate_turn_service || length(var.use_aws_accelerator_ips) > 1
  kurento_nodes                = var.kurento_nodes_count * 2
  processing_nodes             = var.processing_nodes_count * 2
  play_nodes                   = var.play_nodes_count * 2
  turn_nodes                   = local.use_turn_nodes ? 2 : 0
  cidr_block_subnet_public_1   = cidrsubnet(var.vpc_cidr_block, 8, 1)
  cidr_block_subnet_public_2   = cidrsubnet(var.vpc_cidr_block, 8, 2)
  cidr_block_subnet_private_1  = cidrsubnet(var.vpc_cidr_block, 8, 3)
  cidr_block_subnet_private_2  = cidrsubnet(var.vpc_cidr_block, 8, 4)
  efs_mount_ip_address_subnet1 = cidrhost(var.vpc_cidr_block, 1 * 256 + 100) //1.5
  efs_mount_ip_address_subnet2 = cidrhost(var.vpc_cidr_block, 2 * 256 + 100) //2.5
  kurento_nodes_private_ips    = [for a in range(local.kurento_nodes) : cidrhost(var.vpc_cidr_block, (a % 2 == 0 ? 1 : 2) * 256 + 10 + a)]
  processing_nodes_private_ips = [for a in range(local.processing_nodes) : cidrhost(var.vpc_cidr_block, (a % 2 == 0 ? 1 : 2) * 256 + 101 + a)]
  turn_nodes_private_ips       = [for a in range(local.turn_nodes) : cidrhost(var.vpc_cidr_block, (a % 2 == 0 ? 1 : 2) * 256 + 150 + a)]
  play_nodes_private_ips       = [for a in range(local.play_nodes) : cidrhost(var.vpc_cidr_block, (a % 2 == 0 ? 1 : 2) * 256 + 200 + a)]
  create_efs                   = var.custom_efs_address == null || length(var.custom_efs_address) == 0
  efs_dns_name                 = local.create_efs ? aws_efs_file_system.recording-efs[0].dns_name : var.custom_efs_address

  remote_efs_validation = var.remote_efs_address == null ? true : (var.media_input_mount_dir != var.media_output_mount_dir ? true : tobool("When you are using remote_efs_address -> media_input_mount_dir must be different from media_output_mount_dir"))
  getLatest             = lower(var.ami_version) == "latest"
}