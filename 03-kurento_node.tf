locals {  
  kurento_instance_names = [for a in range(var.nodes_count):"KurentoWorker-${a+1}-${var.tenant_id}-${var.infrastructure_purpose}"]
}


data "aws_ami" "kurento_worker_ami" {
  most_recent = true
  owners      = ["376474804475"]

  filter {
    name = "name"
    values = [
      "kurento-prod-ami-*"
    ]
  }

}


data "template_file" "kurento_worker_init" {
  count = var.nodes_count
  template = file("./config/kurento-worker-init.tpl")
  vars = {
    kurento_service_log_file_path = "/var/log/kurento-media-server/*.log"
    kurento_log_group_name        = aws_cloudwatch_log_group.kurento_log_group.name
    kurento_log_stream_name       = aws_cloudwatch_log_stream.kurento_log_streams[count.index].name
    coturn_service_log_file_path  = "/var/log/turnserver/turnserver.log"
    coturn_log_group_name         = aws_cloudwatch_log_group.kurento_log_group.name
    coturn_log_stream_name        = aws_cloudwatch_log_stream.coturn_log_streams[count.index].name
    log_name                      = var.cloudwatch_kurento_worker_log_name

    coturn_listener_port     = var.coturn_listener_port
    coturn_alt_listener_port = var.coturn_alt_listener_port
    internal_ip              = local.kurento_nodes_private_ips[count.index]
    turn_server_username     = random_string.random_username.result
    turn_server_password     = random_password.password.result
    turn_server_min_port     = var.min_port
    turn_server_max_port     = var.max_port


    kurento_aws_monitoring_access_key = var.kurento_monitoring_aws_access_key
    kurento_aws_monitoring_secret_key = var.kurento_monitoring_aws_secret_key
    aws_region                        = var.deployment_region
    kurento_stats_namespace           = var.kurento_stats_server_namespace
    instance_name                     = local.kurento_instance_names[count.index]


    efs_dns_name     = aws_efs_file_system.recording-efs.dns_name
    media_output_dir = var.media_output_dir

  }
}

resource "aws_eip_association" "eip_assoc" {
  count         = var.use_elastic_ip ? var.nodes_count : 0
  instance_id   = aws_instance.kurento_worker[count.index].id
  allocation_id = aws_eip.eip[count.index].id
}


resource "aws_instance" "kurento_worker" {
  count                = var.nodes_count
  ami                  = data.aws_ami.kurento_worker_ami.id
  instance_type        = var.ec2_type
  subnet_id            = (count.index % 2 == 0 ? aws_subnet.main-public-1.id : aws_subnet.main-public-2.id )
  iam_instance_profile = aws_iam_instance_profile.CloudWatch_Profile.name
  private_ip           = local.kurento_nodes_private_ips[count.index]
  user_data            = data.template_file.kurento_worker_init[count.index].rendered

  monitoring    = true
  ebs_optimized = true

  # EC2 instances should disable IMDS or require IMDSv2 as this can be related to the weaponization phase of kill chain
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  vpc_security_group_ids = [
    aws_security_group.kurento_worker_sg.id
  ]

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
  }

}

