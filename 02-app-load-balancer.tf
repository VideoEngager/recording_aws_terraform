resource "aws_lb_target_group" "kurento_target_group" {
  name     = "k-tg-${var.tenant_id}-${var.infrastructure_purpose}"
  port     = 8888
  protocol = "HTTP"
  vpc_id   = aws_vpc.recording_vpc.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }


  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true

  }


  health_check {
    enabled             = "true"
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = 426
  }


}



resource "aws_lb" "recording_load_balancer" {
  name               = "RecLB-${var.tenant_id}-${var.infrastructure_purpose}"
  internal           = true
  load_balancer_type = "application"
  subnets = [
    aws_subnet.main-public-1.id,
    aws_subnet.main-public-2.id
  ]
  security_groups = [
    aws_security_group.lb_sg.id
  ]

  idle_timeout = 900
  // enable_deletion_protection = true

  tags = {
    Name        = "RecordingLoadBalancer-${var.infrastructure_purpose}"
    Environment = var.infrastructure_purpose
  }

  lifecycle {
    ignore_changes = [
      security_groups
    ]
  }

}


resource "aws_lb_listener" "kurento_listener" {
  load_balancer_arn = aws_lb.recording_load_balancer.arn
  port              = "8888"

  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.kurento_target_group.arn
    type             = "forward"
  }


}







resource "aws_lb_listener_rule" "kurento_rule" {
  listener_arn = aws_lb_listener.kurento_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kurento_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/kurento/"]
    }

  }
}



resource "aws_lb_target_group" "processing_target_group" {
  name     = "ptg-${var.tenant_id}-${var.infrastructure_purpose}"
  port     = var.recording_service_listen_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.recording_vpc.id


  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }


  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true

  }

  health_check {
    enabled             = "true"
    protocol            = "HTTP"
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
  }
}

resource "aws_lb_listener" "processing_listener" {
  load_balancer_arn = aws_lb.recording_load_balancer.arn
  port              = var.recording_endpoint_port

  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.processing_target_group.arn
    type             = "forward"
  }


}



resource "aws_lb_listener_rule" "processing_rule" {
  listener_arn = aws_lb_listener.processing_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.processing_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }

  }
}

resource "aws_lb_target_group" "archiver_target_group" {
  count    = var.use_archiver_service ? 1 : 0
  name     = "archtg-${var.tenant_id}-${var.infrastructure_purpose}"
  port     = var.archiver_service_listen_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.recording_vpc.id


  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }


  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true

  }

  health_check {
    enabled             = "true"
    protocol            = "HTTP"
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
  }
}

resource "aws_lb_listener" "archiver_listener" {
  count             = var.use_archiver_service ? 1 : 0
  load_balancer_arn = aws_lb.recording_load_balancer.arn
  port              = var.archiver_service_listen_port

  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.archiver_target_group[0].arn
    type             = "forward"
  }


}



resource "aws_lb_listener_rule" "archiver_rule" {
  count        = var.use_archiver_service ? 1 : 0
  listener_arn = aws_lb_listener.archiver_listener[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.archiver_target_group[0].arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }

  }
}