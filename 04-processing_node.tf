data "aws_ami" "processing_worker_ami" {
  most_recent = true
  owners      = ["376474804475"]

  filter {
    name = "name"
    values = [
      "processing-prod-ami-*"
    ]
  }

}


locals {
  reporter_url = "${lookup(var.reporter_host, var.infrastructure_purpose)}${var.reporter_path}"
}


data "template_file" "processing_worker_init" {
  count = var.nodes_count
  template = file("./config/processing-worker-init.tpl")

  vars = {

    recsvc_listen_port        = var.recording_service_listen_port
    mixer_tool                = var.mixer_tool
    genesys_webdav_server_url = var.genesys_webdav_server_url
    genesys_username          = var.genesys_username
    genesys_password          = var.genesys_password
    reporter_url              = local.reporter_url

    service_log_file_path = "/recsvc/log/logrecsvc_*"
    log_group_name        = aws_cloudwatch_log_group.recsvc_log_group.name
    log_stream_name       = aws_cloudwatch_log_stream.recsvc_log_stream_processing_units[count.index].name


    efs_dns_name         = local.create_efs ? aws_efs_file_system.recording-efs[0].dns_name : var.custom_efs_address
    media_output_dir     = var.media_output_dir
    media_mixer_dir      = var.media_mixer_dir
    media_file_ready_dir = var.media_file_ready_dir

  }
}





resource "aws_instance" "processing_worker" {
  count                = var.use_docker_workers ? 0 : var.nodes_count
  ami                  = data.aws_ami.processing_worker_ami.id
  instance_type        = var.pn_ec2_type
  subnet_id            = (count.index % 2 == 0 ? aws_subnet.main-public-1.id : aws_subnet.main-public-2.id)
  iam_instance_profile = aws_iam_instance_profile.CloudWatch_Profile.name
  private_ip           = local.processing_nodes_private_ips[count.index]
  user_data            = data.template_file.processing_worker_init[count.index].rendered

  monitoring    = true
  ebs_optimized = true

  # EC2 instances should disable IMDS or require IMDSv2 as this can be related to the weaponization phase of kill chain
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 16
  }

  vpc_security_group_ids = [
    aws_security_group.processing_worker_sg.id
  ]

  depends_on = [
    aws_efs_file_system.recording-efs,
    aws_cloudwatch_log_group.recsvc_log_group,
    aws_cloudwatch_log_stream.recsvc_log_stream_processing_units,
    aws_efs_mount_target.kurento-worker-1,
    aws_efs_mount_target.kurento-worker-2
  ]

  tags = {
    Name        = "ProcessingWorker-${count.index+1}-${var.tenant_id}-${var.infrastructure_purpose}"
    Environment = var.infrastructure_purpose
  }

}

resource "aws_lb_target_group_attachment" "processing_target_group_attachment" {
  count            = var.use_docker_workers ? 0 : var.nodes_count
  target_group_arn = aws_lb_target_group.processing_target_group.arn
  target_id        = aws_instance.processing_worker[count.index].id
  port             = var.recording_service_listen_port
}
