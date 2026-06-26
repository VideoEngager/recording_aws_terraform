variable "resource_prefix" {
  type    = string
  default = "recording-azure-1"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "image_rg_name" {
  type    = string
  default = "recording-amis"
}

variable "kurento_image_name_prefix" {
  type    = string
  default = "kurento-prod-image-"
}

variable "processing_image_name_prefix" {
  type    = string
  default = "processing-prod-image-"
}

variable "image_tag_version" {
  type    = string
  default = "v1"
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

variable "kurento_listen_port" {
  type    = number
  default = 8888
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
  type        = string
  default     = "https://videome.leadsecure.com"
  description = "rest server address:port for the RecAPI"
}


variable "reporter_path" {
  type        = string
  default     = "/api/recordings"
  description = "rest server path for the RecAPI"
}

variable "use_archiver_service" {
  default     = false
  type        = bool
  description = "if true enables archiver service"
}

variable "use_verint_connector_service" {
  default     = false
  type        = bool
  description = "if true enables verint connector service"
}

variable "verint_connector_listen_port" {
  type    = number
  default = 7005
}

variable "use_aws_transcribe_service" {
  default     = false
  type        = bool
  description = "if true enables AWS transcribe service"
}

variable "aws_transcribe_listen_port" {
  type    = number
  default = 7006
}

variable "appgw_capacity" {
  type        = number
  default     = 1
  description = "Instance count for the Application Gateway (Standard_v2)."
}

variable "appgw_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Source CIDR blocks allowed inbound to Application Gateway listener ports. Use specific /32 or subnet ranges to restrict access."
}

variable "vm_size" {
  type        = string
  default     = "Standard_B1s"
  description = "VM size for kurento and processing instances. Must be available in all deployment availability zones (e.g. Standard_B2ats_v2 when Standard_B1s has capacity restrictions)."
}
