resource "aws_lb" "play_load_balancer" {
  count              = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  name               = "RecPlay-${var.tenant_id}-${var.infrastructure_purpose}"
  internal           = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.main-public-1.id,
    aws_subnet.main-public-2.id
  ]
  security_groups = [
    aws_security_group.play_lb_sg.id
  ]

  idle_timeout = 900
  // enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.recording_logs.bucket
    prefix  = "Play-${var.lb_prefix}"
    enabled = true
  }

  tags = {
    Name        = "RecordingPlayLoadBalancer-${var.tenant_id}"
    Environment = var.infrastructure_purpose
  }

}

resource "aws_lb_target_group" "play_target_group" {
  count    = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  name     = "playtg-${var.tenant_id}-${var.infrastructure_purpose}"
  port     = var.play_listener_port
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
    path                = "/play/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30  
    matcher             = 200
  }
}

resource "aws_lb_listener" "play_listener" {
  count             = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  load_balancer_arn = aws_lb.play_load_balancer[0].arn
  port              = var.play_listener_port

  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.play_target_group[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "play_rule" {
  count        = (var.use_docker_workers && !var.use_play_service) ? 0 : 1
  listener_arn = aws_lb_listener.play_listener[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.play_target_group[0].arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}





