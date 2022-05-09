variable "access_key" {}
variable "secret_key" {}

variable "kurento_monitoring_aws_access_key" {
  default = ""
}
variable "kurento_monitoring_aws_secret_key" {
  default = ""
}

variable "deployment_region" {}
variable "availability_zone_1" {}
variable "availability_zone_2" {}

variable "ec2_type" {}
variable "pn_ec2_type" {}


variable "tenant_id" {
  default = "customer"
}

variable "media_output_dir" {
  default = "/rec"
}

variable "media_mixer_dir" {
  default = "/outdir"
}

variable "media_file_ready_dir" {
  default = "/s3"
}


variable "infrastructure_purpose" {
  default = "prod"
}

variable "isEFSEncrypted" {
  default     = "true"
  description = "Controls the encryption of data at rest. If true, the disk will be encrypted."
}


variable "recording_endpoint_port" {
  type    = number
  default = 7002
}

variable "recording_service_listen_port" {
  type    = number
  default = 7002
}

variable "mixer_tool" {
  type        = string
  default     = "ffmpeg"
  description = "ffmpeg for Linux and full path to ffmpeg tool for Windows"
}

variable "genesys_webdav_server_url" {
  type        = string
  description = "WebDAV server URL"
  default     = ""
}


variable "genesys_username" {
  type        = string
  description = "user name if authentication (basic/digest) is required"
  default     = ""
}


variable "genesys_password" {
  type        = string
  description = "password  if authentication (basic/digest) is required"
  default     = ""
}



variable "reporter_host" {
  default = {
    "prod"    = "https://videome.leadsecure.com"
    "staging" = "https://videome.leadsecure.com"

  }
  description = "rest server address:port for the RecAPI"
}


variable "reporter_path" {
  type        = string
  default     = "/api/recordings"
  description = "rest server path for the RecAPI"
}


variable "min_port" {
  default     = 55002
  description = "Lower bound of the UDP port range for relay endpoints allocation."
}


variable "max_port" {
  default     = 65535
  description = "Upper bound of the UDP port range for relay endpoints allocation."
}



variable "coturn_listener_port" {
  default = 3478
}


variable "coturn_alt_listener_port" {
  default = 55000
}


variable "vpc_cidr_block" {}
variable "cidr_block_recording_gateway" {
  default = "0.0.0.0/0"
}

variable "csi_vpc_id" {
  default = "vpc-0f1ceef6cafda43b9"
}


variable "controlling_vpc_cidr_block" {
  default     = "10.77.0.0/16"
  description = "VPC CIRD for SmartVideo Controlling Infrastructure"
}



variable "csi_prod_deployment_region" {
  default     = "us-west-2"
  description = "Deployment region of the signaling and controling infrastructure"

}


variable "lb_prefix" {
  default = "lb_log"
}



variable "cloudwatch_kurento_worker_log_name" {
  default = "kurento_workers_logs"
}


variable "aws_account_id" { }


variable "kurento_stats_server_namespace" {
  default = "Kurento-customer"
}


variable "s3_bucket_force_destroy" {
  default = true
}

