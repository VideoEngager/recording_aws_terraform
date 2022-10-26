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
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PLAY-WORK-SG-${var.tenant_id}-${var.infrastructure_purpose}"
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


  // port range is required for turn server
  ingress {
    from_port   = 3478
    to_port     = 3479
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  // port range is required for turn server
  ingress {
    from_port   = 3478
    to_port     = 3479
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  // port range is required for turn server
  ingress {
    from_port   = 55000
    to_port     = 55501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  // port range is required for turn server
  ingress {
    from_port   = 55000
    to_port     = 55501
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
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
    from_port = 7002
    to_port   = 7002
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