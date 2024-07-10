variable "access_key" {
  type = string
}
variable "secret_key" {
  type = string
}

variable "kurento_monitoring_aws_access_key" {
  default = ""
  type    = string
}
variable "kurento_monitoring_aws_secret_key" {
  default = ""
  type    = string
}

variable "deployment_region" {
  type = string
}
variable "availability_zone_1" {
  default = "a"
  type    = string
}
variable "availability_zone_2" {
  default = "b"
  type    = string
}

variable "ec2_type" {
  default = "t3.small"
  type    = string
}
variable "pn_ec2_type" {
  default = "t3.small"
  type    = string
}
variable "play_ec2_type" {
  default = "t3.small"
  type    = string
}

variable "tenant_id" {
  default = "customer"
  type    = string
}

variable "media_input_mount_dir" {
  default = "/rec"
  type    = string
}

variable "media_output_mount_dir" {
  default = "/rec"
  type    = string
}

variable "media_mixer_dir" {
  default = "/outdir"
  type    = string
}

variable "media_file_ready_dir" {
  default = "/s3"
  type    = string
}


variable "infrastructure_purpose" {
  default = "prod"
  type    = string
}

variable "isEFSEncrypted" {
  type        = bool
  default     = true
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

variable "archiver_service_listen_port" {
  type    = number
  default = 7022
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
  type        = number
  default     = 55002
  description = "Lower bound of the UDP port range for relay endpoints allocation."
}


variable "max_port" {
  type        = number
  default     = 65535
  description = "Upper bound of the UDP port range for relay endpoints allocation."
}



variable "coturn_listener_port" {
  type    = number
  default = 3478
}


variable "coturn_alt_listener_port" {
  type    = number
  default = 55000
}

variable "play_listener_port" {
  type    = number
  default = 9001
}

variable "vpc_cidr_block" {
  type = string
}
variable "cidr_block_recording_gateway" {
  type    = string
  default = "0.0.0.0/0"
}

variable "csi_vpc_id" {
  type    = string
  default = "vpc-0f1ceef6cafda43b9"
}

variable "csi_account" {
  type    = string
  default = "376474804475"
}


variable "controlling_vpc_cidr_block" {
  type        = string
  default     = "10.77.0.0/16"
  description = "VPC CIRD for SmartVideo Controlling Infrastructure"
}



variable "csi_prod_deployment_region" {
  type        = string
  default     = "us-west-2"
  description = "Deployment region of the signaling and controling infrastructure"

}


variable "lb_prefix" {
  type    = string
  default = "lb_log"
}



variable "cloudwatch_kurento_worker_log_name" {
  type    = string
  default = "kurento_workers_logs"
}


variable "aws_account_id" {
  type = string
}


variable "kurento_stats_server_namespace" {
  type    = string
  default = "Kurento-customer"
}


variable "s3_bucket_force_destroy" {
  type    = bool
  default = true
}

variable "use_private_link" {
  default     = false
  type        = bool
  description = "if true usage of AWS Private Link instead of VPC Peering"
}

variable "use_elastic_ip" {
  default     = false
  type        = bool
  description = "if true usage of Elastic IP addresses of kurento nodes"
}

variable "use_docker_workers" {
  default     = false
  type        = bool
  description = "if true usage of Docker instance nodes"
}

variable "aws_ecr_docker_token" {
  default     = ""
  type        = string
  description = "Temporary token used for docker login to AWS ECR service"
}

variable "docker_worker_log_dir" {
  type    = string
  default = "/var/log/videoengager"
}

variable "docker_ec2_type" {
  type    = string
  default = "t3.medium"
}

variable "use_play_service" {
  default     = false
  type        = bool
  description = "if true add play service insance/s"
}

variable "play_service_cert_arn" {
  default     = ""
  type        = string
  description = "If in use .. add https support for play load balancer otherwise uses http"
}

variable "custom_efs_address" {
  default     = ""
  type        = string
  description = "If in use .. do not create efs .. use provided in value one"
}

variable "kurento_nodes_count" {
  default = 1
  type    = number
  validation {
    condition     = var.kurento_nodes_count < 20
    error_message = "The value of kurento_nodes_count must be less than 20."
  }
}

variable "processing_nodes_count" {
  default = 1
  type    = number
  validation {
    condition     = var.processing_nodes_count < 20
    error_message = "The value of processing_nodes_count must be less than 20."
  }
}

variable "play_nodes_count" {
  default = 1
  type    = number
  validation {
    condition     = var.play_nodes_count < 20
    error_message = "The value of play_nodes_count must be less than 20."
  }
}

variable "use_separate_turn_service" {
  default     = false
  type        = bool
  description = "if true creates pair of coturn ec2 instances"
}

variable "turn_ec2_type" {
  default = "t3.small"
}

variable "remote_efs_address" {
  default     = null
  type        = string
  description = "if not null app uses this filesystem to store final recording files.Please note that you must use different values for media_input_mount_dir and media_output_mount_dir "
}

variable "use_archiver_service" {
  default     = false
  type        = bool
  description = "if true enables archiver service"
}

variable "ami_version" {
  default     = "latest"
  type        = string
  description = "Recording version to install"
}

variable "use_aws_accelerator_ips" {
  default     = []
  type        = list(string)
  description = "if in use will place separate kurento instances in private availability groups and add ips as kurento's externalIPv4 param."
}

variable "allow_ssh_access_ips" {
  default     = []
  type        = list(string)
  description = "If set allows ssh access from provided list of ip addresses, Example 10.11.12.13/32 to allow 10.11.12.13 ip ssh access. "
}

variable "use_verint_connector_service" {
  default     = false
  type        = bool
  description = "if true enables verint connector service"
}

variable "verint_connector_listen_port" {
  type = number
  default = 7005
}
