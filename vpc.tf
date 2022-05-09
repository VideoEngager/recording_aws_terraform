# VPC
resource "aws_vpc" "recording_vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  lifecycle {
    create_before_destroy = true
  }


  tags = {
    Name = "Recording-VPC-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}


# Subnets
resource "aws_subnet" "main-public-1" {
  vpc_id                  = aws_vpc.recording_vpc.id
  cidr_block              = local.cidr_block_subnet_public_1
  map_public_ip_on_launch = "true"
  availability_zone       = "${var.deployment_region}${var.availability_zone_1}"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "main-public-1-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}


resource "aws_subnet" "main-public-2" {
  vpc_id                  = aws_vpc.recording_vpc.id
  cidr_block              = local.cidr_block_subnet_public_2
  map_public_ip_on_launch = "true"
  availability_zone       = "${var.deployment_region}${var.availability_zone_2}"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "main-public-2-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}



resource "aws_subnet" "main-private-1" {
  vpc_id                  = aws_vpc.recording_vpc.id
  cidr_block              = local.cidr_block_subnet_private_1
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.deployment_region}${var.availability_zone_1}"


  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "main-private-1-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}


resource "aws_subnet" "main-private-2" {
  vpc_id                  = aws_vpc.recording_vpc.id
  cidr_block              = local.cidr_block_subnet_private_2
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.deployment_region}${var.availability_zone_2}"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "main-private-2-${var.tenant_id}-${var.infrastructure_purpose}"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "recording_gateway" {
  vpc_id = aws_vpc.recording_vpc.id

  tags = {
    Name = "RecordingGateway-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}

# Route tables
resource "aws_route_table" "recording_public" {
  vpc_id = aws_vpc.recording_vpc.id
 
  lifecycle {
    create_before_destroy = true

  }

  tags = {
    Name = "vpc-route-table-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}

resource "aws_route" "internet_access" {
  route_table_id            = aws_route_table.recording_public.id
  destination_cidr_block    = var.cidr_block_recording_gateway
  gateway_id                = aws_internet_gateway.recording_gateway.id

  depends_on = [
    aws_route_table.recording_public
  ]

}


# route associations public
resource "aws_route_table_association" "main-public-1-a" {
  subnet_id      = aws_subnet.main-public-1.id
  route_table_id = aws_route_table.recording_public.id

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_route_table_association" "main-public-2-a" {
  subnet_id      = aws_subnet.main-public-2.id
  route_table_id = aws_route_table.recording_public.id

  lifecycle {
    create_before_destroy = true
  }

}
















