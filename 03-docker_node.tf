locals {
  docker_instance_names    = [for a in range(local.kurento_nodes) : "Rec-DockerWorker-${a + 1}-${var.tenant_id}-${var.infrastructure_purpose}"]
  reporter_docker_play_url = lookup(var.reporter_host, var.infrastructure_purpose)
}


data "aws_ami" "worker_ami_centos" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name = "product-code"
    values = [
      "cvugziknvmxgqna9noibqnnsy"
    ]
  }

}


data "template_file" "docker_worker_init" {
  count    = local.kurento_nodes
  template = file("./config/docker-centos7-worker-init.tpl")
  vars = {
    playback_base_url = local.reporter_docker_play_url

    coturn_listener_port   = var.coturn_listener_port
    play_listener_port     = var.play_listener_port
    archiver_listener_port = var.archiver_service_listen_port
    internal_ip            = local.kurento_nodes_private_ips[count.index]
    turn_server_username   = random_string.random_username.result
    turn_server_password   = random_password.password.result
    image_version          = var.ami_version

    efs_dns_name     = local.create_efs ? aws_efs_file_system.recording-efs[0].dns_name : var.custom_efs_address
    media_output_dir = var.media_input_mount_dir

    docker_token = var.aws_ecr_docker_token
    log_dir      = var.docker_worker_log_dir
  }
}

resource "aws_eip_association" "docker_eip_assoc" {
  count         = (var.use_elastic_ip && var.use_docker_workers) ? local.kurento_nodes : 0
  instance_id   = aws_instance.docker_worker[count.index].id
  allocation_id = aws_eip.eip[count.index].id
}


resource "aws_instance" "docker_worker" {
  count                = var.use_docker_workers ? local.kurento_nodes : 0
  ami                  = data.aws_ami.worker_ami_centos.id
  instance_type        = var.docker_ec2_type
  subnet_id            = (count.index % 2 == 0 ? aws_subnet.main-public-1.id : aws_subnet.main-public-2.id)
  iam_instance_profile = aws_iam_instance_profile.CloudWatch_Profile.name
  private_ip           = local.kurento_nodes_private_ips[count.index]
  user_data            = data.template_file.docker_worker_init[count.index].rendered

  monitoring    = true
  ebs_optimized = true
  # key_name = "sshkeyname"

  root_block_device {
    volume_size = 16
  }

  # EC2 instances should disable IMDS or require IMDSv2 as this can be related to the weaponization phase of kill chain
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  vpc_security_group_ids = concat([
    aws_security_group.kurento_worker_sg.id,
    aws_security_group.processing_worker_sg.id,
    aws_security_group.play_worker_sg.id],
  aws_security_group.ssh_access_sg.*.id)

  depends_on = [
    aws_efs_file_system.recording-efs,
    aws_efs_mount_target.kurento-worker-1,
    aws_efs_mount_target.kurento-worker-2
  ]

  tags = {
    Name        = local.docker_instance_names[count.index]
    Environment = var.infrastructure_purpose
  }
}

resource "aws_lb_target_group_attachment" "docker_processing_target_group_attachment" {
  count            = var.use_docker_workers ? local.kurento_nodes : 0
  target_group_arn = aws_lb_target_group.processing_target_group.arn
  target_id        = aws_instance.docker_worker[count.index].id
  port             = var.recording_service_listen_port
}

resource "aws_lb_target_group_attachment" "docker_kurento_target_group_attachment" {
  count            = var.use_docker_workers ? local.kurento_nodes : 0
  target_group_arn = aws_lb_target_group.kurento_target_group.arn
  target_id        = aws_instance.docker_worker[count.index].id
  port             = 8888
}

resource "aws_lb_target_group_attachment" "docker_play_target_group_attachment" {
  count            = var.use_docker_workers && var.use_play_service ? local.kurento_nodes : 0
  target_group_arn = aws_lb_target_group.play_target_group[0].arn
  target_id        = aws_instance.docker_worker[count.index].id
  port             = var.play_listener_port
}

resource "aws_lb_target_group_attachment" "docker_archiver_target_group_attachment" {
  count            = var.use_docker_workers && var.use_archiver_service ? local.kurento_nodes : 0
  target_group_arn = aws_lb_target_group.archiver_target_group[0].arn
  target_id        = aws_instance.docker_worker[count.index].id
  port             = var.archiver_service_listen_port
}

resource "aws_lb_target_group_attachment" "docker_verint_connector_target_group_attachment" {
  count            = var.use_docker_workers && var.use_verint_connector_service ? local.kurento_nodes : 0
  target_group_arn = aws_lb_target_group.verint_connector_target_group[0].arn
  target_id        = aws_instance.docker_worker[count.index].id
  port             = var.verint_connector_listen_port
}
