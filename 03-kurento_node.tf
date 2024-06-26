locals {
  kurento_instance_names = var.use_docker_workers ? [] : [for a in range(local.kurento_nodes) : "KurentoWorker-${a + 1}-${var.tenant_id}-${try(data.aws_ami.kurento_worker_ami[0].tags["Version"], var.ami_version)}"]
}


data "aws_ami" "kurento_worker_ami" {
  most_recent = true
  owners      = ["376474804475"]
  count       = var.use_docker_workers ? 0 : 1
  filter {
    name = "name"
    values = [
      "kurento-${local.getLatest ? "*" : var.ami_version}-ami-*"
    ]
  }


  # filter {
  #   name = local.getLatest ? "tag-key" : "tag:Version"
  #   values = [
  #     local.getLatest ? "Latest" : var.ami_version
  #   ]
  # }

}


data "template_file" "kurento_worker_init" {
  count    = var.use_docker_workers ? 0 : local.kurento_nodes
  template = local.use_turn_nodes ? file("./config/kurento-noturn-worker-init.tpl") : file("./config/kurento-worker-init.tpl")
  vars = {
    kurento_service_log_file_path = "/var/log/kurento-media-server/*.log"
    kurento_log_group_name        = aws_cloudwatch_log_group.kurento_log_group.name
    kurento_log_stream_name       = aws_cloudwatch_log_stream.kurento_log_streams[count.index].name
    coturn_service_log_file_path  = "/var/log/turnserver/turnserver.log"
    coturn_log_group_name         = aws_cloudwatch_log_group.kurento_log_group.name
    coturn_log_stream_name        = local.use_turn_nodes ? aws_cloudwatch_log_stream.kurento_log_streams[count.index].name : aws_cloudwatch_log_stream.coturn_log_streams[count.index].name
    log_name                      = var.cloudwatch_kurento_worker_log_name

    coturn_listener_port     = var.coturn_listener_port
    coturn_alt_listener_port = var.coturn_alt_listener_port
    internal_ip              = local.kurento_nodes_private_ips[count.index]
    turn_server_username     = random_string.random_username.result
    turn_server_password     = random_password.password.result
    turn_server_min_port     = var.min_port
    turn_server_max_port     = var.max_port
    turn_internal_ip         = local.use_turn_nodes ? local.turn_nodes_private_ips[(count.index % 2 == 0) ? 0 : 1] : "127.0.0.1"
    kurento_host_ip          = local.use_turn_nodes ? var.use_aws_accelerator_ips[(count.index % 2 == 0) ? 0 : 1] : ""

    kurento_aws_monitoring_access_key = var.kurento_monitoring_aws_access_key
    kurento_aws_monitoring_secret_key = var.kurento_monitoring_aws_secret_key
    aws_region                        = var.deployment_region
    kurento_stats_namespace           = var.kurento_stats_server_namespace
    instance_name                     = local.kurento_instance_names[count.index]


    efs_dns_name     = local.create_efs ? aws_efs_file_system.recording-efs[0].dns_name : var.custom_efs_address
    media_output_dir = var.media_input_mount_dir

  }
}

resource "aws_eip_association" "eip_assoc" {
  count = (!local.use_turn_nodes && var.use_elastic_ip && !var.use_docker_workers) ? local.kurento_nodes : 0
  # count  = 2 
  instance_id   = aws_instance.kurento_worker[count.index].id
  allocation_id = aws_eip.eip[count.index].id
}


resource "aws_instance" "kurento_worker" {
  count                = var.use_docker_workers ? 0 : local.kurento_nodes
  ami                  = data.aws_ami.kurento_worker_ami[0].id
  instance_type        = var.ec2_type
  subnet_id            = (count.index % 2 == 0 ? (local.use_turn_nodes ? aws_subnet.main-private-1.id : aws_subnet.main-public-1.id) : (local.use_turn_nodes ? aws_subnet.main-private-2.id : aws_subnet.main-public-2.id))
  iam_instance_profile = aws_iam_instance_profile.CloudWatch_Profile.name
  private_ip           = local.use_turn_nodes ? null : local.kurento_nodes_private_ips[count.index]
  user_data            = data.template_file.kurento_worker_init[count.index].rendered

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
    aws_security_group.kurento_worker_sg.id],
    aws_security_group.ssh_access_sg.*.id
  )



  depends_on = [
    aws_efs_file_system.recording-efs,
    aws_cloudwatch_log_group.kurento_log_group,
    aws_cloudwatch_log_stream.kurento_log_streams,
    aws_efs_mount_target.kurento-worker-1,
    aws_efs_mount_target.kurento-worker-2
  ]

  tags = {
    Name        = local.kurento_instance_names[count.index]
    Environment = var.infrastructure_purpose
    Version     = try(data.aws_ami.kurento_worker_ami[0].tags["Version"], var.ami_version)
  }

}

resource "aws_lb_target_group_attachment" "kurento_target_group_attachment" {
  count            = var.use_docker_workers ? 0 : local.kurento_nodes
  target_group_arn = aws_lb_target_group.kurento_target_group.arn
  target_id        = aws_instance.kurento_worker[count.index].id
  port             = 8888
}
