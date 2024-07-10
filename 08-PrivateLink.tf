resource "aws_vpc_endpoint_service" "private_link_service" {
  count                      = var.use_private_link ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.private_link[count.index].arn]

  tags = {
    Name        = "RecordingPrivateLinkService-${var.infrastructure_purpose}"
    Environment = var.infrastructure_purpose
  }
}

resource "aws_vpc_endpoint_service_allowed_principal" "allow_videoengager" {
  count                   = var.use_private_link ? 1 : 0
  vpc_endpoint_service_id = aws_vpc_endpoint_service.private_link_service[count.index].id
  principal_arn           = "arn:aws:iam::376474804475:root"
}

resource "aws_lb" "private_link" {
  count              = var.use_private_link ? 1 : 0
  name               = "rec-pl-nlb-${var.tenant_id}-${var.infrastructure_purpose}"
  internal           = true
  load_balancer_type = "network"

  subnets = [
    aws_subnet.main-public-1.id,
    aws_subnet.main-public-2.id
  ]

  tags = {
    Name        = "rec-private-link-nlb-${var.tenant_id}-${var.infrastructure_purpose}"
    Environment = var.infrastructure_purpose
  }
}

resource "aws_lb_listener" "private_link_kurento" {
  count             = var.use_private_link ? 1 : 0
  load_balancer_arn = aws_lb.private_link[count.index].arn
  port              = 8888
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_link_kurento[count.index].arn
  }
}

resource "aws_lb_target_group" "private_link_kurento" {
  count       = var.use_private_link ? 1 : 0
  name        = "pl-k-tg-${var.tenant_id}-${var.infrastructure_purpose}"
  port        = 8888
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.recording_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

}

resource "aws_lb_target_group_attachment" "private_link_kurento" {
  count            = var.use_private_link ? 1 : 0
  target_group_arn = aws_lb_target_group.private_link_kurento[count.index].arn
  target_id        = aws_lb.recording_load_balancer.arn
  port             = 8888

  depends_on = [
    aws_lb_listener.private_link_kurento,
    aws_lb.recording_load_balancer,
    aws_lb_target_group.private_link_kurento
  ]
}


resource "aws_lb_listener" "private_link_processing" {
  count             = var.use_private_link ? 1 : 0
  load_balancer_arn = aws_lb.private_link[count.index].arn
  port              = var.recording_endpoint_port
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_link_processing[count.index].arn
  }
}

resource "aws_lb_target_group" "private_link_processing" {
  count       = var.use_private_link ? 1 : 0
  name        = "pl-pcs-tg-${var.tenant_id}-${var.infrastructure_purpose}"
  port        = var.recording_endpoint_port
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.recording_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

}

resource "aws_lb_target_group_attachment" "private_link_processing" {
  count            = var.use_private_link ? 1 : 0
  target_group_arn = aws_lb_target_group.private_link_processing[count.index].arn
  target_id        = aws_lb.recording_load_balancer.arn
  port             = var.recording_endpoint_port

  depends_on = [
    aws_lb_listener.private_link_processing,
    aws_lb.recording_load_balancer,
    aws_lb_target_group.private_link_processing
  ]
}

resource "aws_lb_listener" "private_link_efs" {
  count             = var.use_private_link ? 1 : 0
  load_balancer_arn = aws_lb.private_link[count.index].arn
  port              = 2049
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_link_efs[count.index].arn
  }
}

resource "aws_lb_target_group" "private_link_efs" {
  count       = var.use_private_link ? 1 : 0
  name        = "pl-efs-tg-${var.tenant_id}-${var.infrastructure_purpose}"
  port        = 2049
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.recording_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

}

resource "aws_lb_target_group_attachment" "private_link_efs_az_1" {
  count            = var.use_private_link ? 1 : 0
  target_group_arn = aws_lb_target_group.private_link_efs[count.index].arn
  target_id        = local.efs_mount_ip_address_subnet1
  port             = 2049
}

resource "aws_lb_target_group_attachment" "private_link_efs_az_2" {
  count            = var.use_private_link ? 1 : 0
  target_group_arn = aws_lb_target_group.private_link_efs[count.index].arn
  target_id        = local.efs_mount_ip_address_subnet2
  port             = 2049
}

resource "aws_lb_listener" "private_link_archive" {
  count             = (var.use_private_link && var.use_archiver_service) ? 1 : 0
  load_balancer_arn = aws_lb.private_link[count.index].arn
  port              = var.archiver_service_listen_port
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_link_archive[count.index].arn
  }
}

resource "aws_lb_target_group" "private_link_archive" {
  count       = (var.use_private_link && var.use_archiver_service) ? 1 : 0
  name        = "pl-arch-tg-${var.tenant_id}-${var.infrastructure_purpose}"
  port        = var.archiver_service_listen_port
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.recording_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

}

resource "aws_lb_target_group_attachment" "private_link_archive" {
  count            = (var.use_private_link && var.use_archiver_service) ? 1 : 0
  target_group_arn = aws_lb_target_group.private_link_archive[count.index].arn
  target_id        = aws_lb.recording_load_balancer.arn
  port             = var.archiver_service_listen_port

  depends_on = [
    aws_lb_listener.private_link_archive,
    aws_lb.recording_load_balancer,
    aws_lb_target_group.private_link_archive
  ]
}

resource "aws_lb_listener" "private_link_verint_connector" {
  count             = (var.use_private_link && var.use_verint_connector_service) ? 1 : 0
  load_balancer_arn = aws_lb.private_link[count.index].arn
  port              = var.verint_connector_listen_port
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_link_verint_connector[count.index].arn
  }
}

resource "aws_lb_target_group" "private_link_verint_connector" {
  count       = (var.use_private_link && var.use_verint_connector_service) ? 1 : 0
  name        = "pl-verintconn-tg-${var.tenant_id}-${var.infrastructure_purpose}"
  port        = var.verint_connector_listen_port
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.recording_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

}

resource "aws_lb_target_group_attachment" "private_link_verint_connector" {
  count            = (var.use_private_link && var.use_verint_connector_service) ? 1 : 0
  target_group_arn = aws_lb_target_group.private_link_verint_connector[count.index].arn
  target_id        = aws_lb.recording_load_balancer.arn
  port             = var.verint_connector_listen_port

  depends_on = [
    aws_lb_listener.private_link_verint_connector,
    aws_lb.recording_load_balancer,
    aws_lb_target_group.private_link_verint_connector
  ]
}

