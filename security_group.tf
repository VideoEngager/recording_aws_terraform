resource "aws_security_group" "efs_sg" {
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "EFS-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "Ports 2049, 20049, 20449 Open for Smart VPC Control VPC Cidr + Recording VPC Cidr"


  lifecycle {
    create_before_destroy = true
  }


  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    cidr_blocks = [
      var.vpc_cidr_block,
      var.controlling_vpc_cidr_block
    ]
  }



  ingress {
    from_port = 20049
    to_port   = 20049
    protocol  = "tcp"
    cidr_blocks = [
      var.vpc_cidr_block,
      var.controlling_vpc_cidr_block
    ]
  }



  ingress {
    from_port = 20449
    to_port   = 20449
    protocol  = "tcp"
    cidr_blocks = [
      var.vpc_cidr_block,
      var.controlling_vpc_cidr_block
    ]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EFSt-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}



resource "aws_security_group" "processing_worker_sg" {
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "PROC-WORK-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "SSH access from whitelisted hosts + Smart VPC Control VPC Cidr"


  lifecycle {
    create_before_destroy = true
  }


  ingress {
    from_port = var.recording_service_listen_port
    to_port   = var.recording_service_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      local.cidr_block_subnet_public_1,
      local.cidr_block_subnet_public_2
    ]

  }

  ingress {
    from_port = var.archiver_service_listen_port
    to_port   = var.archiver_service_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      local.cidr_block_subnet_public_1,
      local.cidr_block_subnet_public_2
    ]

  }

  ingress {
    from_port = var.verint_connector_listen_port
    to_port   = var.verint_connector_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      local.cidr_block_subnet_public_1,
      local.cidr_block_subnet_public_2
    ]
  }

  ingress {
    from_port = var.aws_transcribe_listen_port
    to_port   = var.aws_transcribe_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      local.cidr_block_subnet_public_1,
      local.cidr_block_subnet_public_2
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PROC-WORK-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}


resource "aws_security_group" "play_worker_sg" {
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "PLAY-WORK-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "Allow playback service port"


  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port = var.play_listener_port
    to_port   = var.play_listener_port
    protocol  = "tcp"
    cidr_blocks = [
      local.cidr_block_subnet_public_1,
      local.cidr_block_subnet_public_2
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "PLAY-WORK-SG-${var.tenant_id}-${var.infrastructure_purpose}"
    Environment = var.infrastructure_purpose
  }

}





resource "aws_security_group" "kurento_worker_sg" {
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "KMS-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "TCP/UDP 55002 - 65535 for relaying media from 0.0.0.0/0 + SSH access from maintenance.videoengager.com + TCP port 8888 for websocket + TCP/UDP ports 55000-55001 for STUN/TURN requests "


  lifecycle {
    create_before_destroy = true
  }


  ingress {
    from_port   = var.min_port
    to_port     = var.max_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.min_port
    to_port     = var.max_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port = 8888
    to_port   = 8888
    protocol  = "tcp"
    cidr_blocks = [
      local.cidr_block_subnet_public_1,
      local.cidr_block_subnet_public_2,
      local.cidr_block_subnet_private_1,
      local.cidr_block_subnet_private_2
    ]
  }

  dynamic "ingress" {
    for_each = length(var.use_aws_accelerator_ips) > 0 ? ["ok"] : []
    content {
      from_port       = 8888
      to_port         = 8888
      protocol        = "tcp"
      prefix_list_ids = [data.aws_ec2_managed_prefix_list.route53healthchecks.id]
    }
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KMS-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}


resource "aws_security_group" "lb_sg" {
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "ELB-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "Allow access through ports 7002 and 8888 from Smart Video VPC"


  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port = var.archiver_service_listen_port
    to_port   = var.archiver_service_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      var.use_private_link ? var.vpc_cidr_block : var.controlling_vpc_cidr_block
    ]
  }

  ingress {
    from_port = var.verint_connector_listen_port
    to_port   = var.verint_connector_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      var.use_private_link ? var.vpc_cidr_block : var.controlling_vpc_cidr_block
    ]
  }

  ingress {
    from_port = var.aws_transcribe_listen_port
    to_port   = var.aws_transcribe_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      var.use_private_link ? var.vpc_cidr_block : var.controlling_vpc_cidr_block
    ]
  }

  ingress {
    from_port = var.recording_service_listen_port
    to_port   = var.recording_service_listen_port
    protocol  = "tcp"
    cidr_blocks = [
      var.use_private_link ? var.vpc_cidr_block : var.controlling_vpc_cidr_block
    ]
  }


  ingress {
    from_port = 8888
    to_port   = 8888
    protocol  = "tcp"
    cidr_blocks = [
      var.use_private_link ? var.vpc_cidr_block : var.controlling_vpc_cidr_block
    ]
  }

  ingress {
    from_port   = var.play_listener_port
    to_port     = var.play_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ELB-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}

resource "aws_security_group" "play_lb_sg" {
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "PlayELB-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "Allow access through ports 443 and 9001"


  lifecycle {
    create_before_destroy = true
  }


  ingress {
    from_port   = var.play_listener_port
    to_port     = var.play_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PlayELB-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}

resource "aws_security_group" "ssh_access_sg" {
  count       = length(var.allow_ssh_access_ips) > 0 ? 1 : 0
  vpc_id      = aws_vpc.recording_vpc.id
  name        = "SSH_ACCESS-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  description = "SSH access from whitelisted hosts"


  lifecycle {
    create_before_destroy = true
  }


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_access_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SSH_ACCESS-SG-${var.tenant_id}-${var.infrastructure_purpose}"
  }

}

resource "aws_security_group_rule" "turn_rule" {
  count             = 2
  type              = "ingress"
  from_port         = 3478
  to_port           = 3479
  protocol          = (count.index % 2) > 0 ? "tcp" : "udp"
  cidr_blocks       = local.use_turn_nodes ? ["0.0.0.0/0"] : [for ip in(length(aws_eip.eip) > 0 ? aws_eip.eip.*.public_ip : aws_instance.kurento_worker.*.public_ip) : "${ip}/32"]
  security_group_id = aws_security_group.kurento_worker_sg.id
}

data "aws_ec2_managed_prefix_list" "route53healthchecks" {
  name = "com.amazonaws.${var.deployment_region}.route53-healthchecks"
}

