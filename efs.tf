resource "aws_efs_file_system" "recording-efs" {
  count            = local.create_efs ? 1 : 0
  creation_token   = "recording-efs-${var.tenant_id}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = var.isEFSEncrypted

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  tags = {
    Name = "RecordingElasticStorage-${var.tenant_id}-${var.infrastructure_purpose}"
  }

  lifecycle {
    ignore_changes = [
      creation_token,
      tags,
    ]
  }
}


resource "aws_efs_mount_target" "kurento-worker-1" {
  count          = local.create_efs ? 1 : 0
  file_system_id = aws_efs_file_system.recording-efs[0].id
  subnet_id      = aws_subnet.main-public-1.id
  ip_address     = local.efs_mount_ip_address_subnet1
  security_groups = [
    aws_security_group.efs_sg.id
  ]
}



resource "aws_efs_mount_target" "kurento-worker-2" {
  count          = local.create_efs ? 1 : 0
  file_system_id = aws_efs_file_system.recording-efs[0].id
  subnet_id      = aws_subnet.main-public-2.id
  ip_address     = local.efs_mount_ip_address_subnet2
  security_groups = [
    aws_security_group.efs_sg.id
  ]
}

