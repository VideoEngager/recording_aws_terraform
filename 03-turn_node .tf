locals {  
  turn_instance_names = [for a in range(local.turn_nodes):"TurnWorker-${a+1}-${var.tenant_id}-${var.infrastructure_purpose}"]
  use_turn_nodes = var.use_separate_turn_service
}


data "template_file" "turn_worker_init" {
  count = local.turn_nodes
  template = file("./config/turn-worker-init.tpl")
  vars = {
    coturn_service_log_file_path  = "/var/log/turnserver/turnserver.log"
    coturn_log_group_name         = aws_cloudwatch_log_group.kurento_log_group.name
    coturn_log_stream_name        = aws_cloudwatch_log_stream.coturn_log_streams[count.index].name
    log_name                      = var.cloudwatch_kurento_worker_log_name

    coturn_listener_port     = var.coturn_listener_port
    coturn_alt_listener_port = var.coturn_alt_listener_port
    internal_ip              = local.turn_nodes_private_ips[count.index]
    turn_server_username     = random_string.random_username.result
    turn_server_password     = random_password.password.result
    turn_server_min_port     = var.min_port
    turn_server_max_port     = var.max_port


    instance_name                     = local.turn_instance_names[count.index]
  }
}

resource "aws_eip_association" "turn_eip_assoc" {
  count         = (local.use_turn_nodes && var.use_elastic_ip && !var.use_docker_workers) ? local.turn_nodes : 0
  instance_id   = aws_instance.turn_worker[count.index].id
  allocation_id = aws_eip.eip[count.index].id
}


resource "aws_instance" "turn_worker" {
  count                = var.use_docker_workers ? 0 : local.turn_nodes
  ami                  = data.aws_ami.kurento_worker_ami.id
  instance_type        = var.turn_ec2_type
  subnet_id            = (count.index % 2 == 0 ? aws_subnet.main-public-1.id : aws_subnet.main-public-2.id )
  iam_instance_profile = aws_iam_instance_profile.CloudWatch_Profile.name
  private_ip           = local.turn_nodes_private_ips[count.index]
  user_data            = data.template_file.turn_worker_init[count.index].rendered

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

  vpc_security_group_ids = [
    aws_security_group.kurento_worker_sg.id
  ]

  depends_on = [
    aws_cloudwatch_log_group.kurento_log_group,
    aws_cloudwatch_log_stream.coturn_log_streams
  ]

  tags = {
    Name        = local.turn_instance_names[count.index]
    Environment = var.infrastructure_purpose
  }

}
