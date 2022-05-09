locals {
  cidr_block_subnet_public_1 =  cidrsubnet(var.vpc_cidr_block, 8, 1)
  cidr_block_subnet_public_2 =  cidrsubnet(var.vpc_cidr_block, 8, 2)
  cidr_block_subnet_private_1 = cidrsubnet(var.vpc_cidr_block, 8, 3)
  cidr_block_subnet_private_2 = cidrsubnet(var.vpc_cidr_block, 8, 4)
  efs_mount_ip_address_subnet1 = cidrhost(var.vpc_cidr_block, 1*256+100) //1.100
  efs_mount_ip_address_subnet2 = cidrhost(var.vpc_cidr_block, 2*256+100) //2.100
  kurento_1_private_ip = cidrhost(var.vpc_cidr_block, 1*256+178) //1.178
  kurento_2_private_ip = cidrhost(var.vpc_cidr_block, 2*256+178) //2.178
}