data "aws_ami" "play_worker_ami" {
  most_recent = true
  owners      = ["376474804475"]
  count = var.use_docker_workers ? 0 : 1

  filter {
    name = "name"
    values = [
      "play-${local.getLatest ? "*" : var.ami_version}-ami-*"
    ]
  }

  
  filter {
    name = local.getLatest ? "tag-key" : "tag:Version"
    values = [
      local.getLatest ? "Latest" : var.ami_version
    ]
  }

}


locals {
  reporter_play_url = "${lookup(var.reporter_host, var.infrastructure_purpose)}"
}


data "template_file" "play_worker_init" {
  count = (var.use_docker_workers || !var.use_play_service) ? 0 : local.play_nodes
  template = file("./config/play-worker-init.tpl")

  vars = {
    playsvc_listen_port   = var.play_listener_port
    reporter_url          = local.reporter_play_url

    service_log_file_path = "/playsvc/log/*"
    log_group_name        = aws_cloudwatch_log_group.playsvc_log_group.name
    log_stream_name       = aws_cloudwatch_log_stream.playsvc_log_stream_processing_units[count.index].name


    efs_dns_name         = local.remote_efs_validation && var.remote_efs_address!=null ? var.remote_efs_address : local.efs_dns_name
    media_output_dir     = var.media_output_mount_dir
    media_mixer_dir      = var.media_mixer_dir
    media_file_ready_dir = var.media_file_ready_dir
  }
}





resource "aws_instance" "play_worker" {
  count                = (var.use_docker_workers || !var.use_play_service) ? 0 : local.play_nodes
  ami                  = data.aws_ami.play_worker_ami[0].id
  instance_type        = var.play_ec2_type
  subnet_id            = (count.index % 2 == 0 ? aws_subnet.main-public-1.id : aws_subnet.main-public-2.id)
  iam_instance_profile = aws_iam_instance_profile.CloudWatch_Profile.name
  #private_ip           = local.play_nodes_private_ips[count.index]
  user_data            = data.template_file.play_worker_init[count.index].rendered

  monitoring    = true
  ebs_optimized = true

  root_block_device {
    volume_size = 16
  }

  # EC2 instances should disable IMDS or require IMDSv2 as this can be related to the weaponization phase of kill chain
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  vpc_security_group_ids = concat([
    aws_security_group.play_worker_sg.id], 
    aws_security_group.ssh_access_sg.*.id
  )

  depends_on = [
    aws_efs_file_system.recording-efs,
    aws_cloudwatch_log_group.playsvc_log_group,
    aws_cloudwatch_log_stream.playsvc_log_stream_processing_units,
    aws_efs_mount_target.kurento-worker-1,
    aws_efs_mount_target.kurento-worker-2,
    aws_instance.processing_worker
  ]

  tags = {
    Name        = "PlayWorker-${count.index+1}-${var.tenant_id}-${data.aws_ami.play_worker_ami[0].tags["Version"]}"
    Environment = var.infrastructure_purpose
    Version     = data.aws_ami.play_worker_ami[0].tags["Version"]
  }

}

resource "aws_lb_target_group_attachment" "play_target_group_attachment" {
  count            = (var.use_docker_workers || !var.use_play_service) ? 0 : local.play_nodes
  target_group_arn = aws_lb_target_group.play_target_group[0].arn
  target_id        = aws_instance.play_worker[count.index].id
  port             = var.play_listener_port
}
