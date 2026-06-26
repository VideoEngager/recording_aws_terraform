# ---------------------------------------------------------------------------
# Azure Monitor (equivalent of AWS CloudWatch)
#
# Mapping from the AWS implementation (05-cloudwatch.tf):
#   AWS CloudWatch Logs (log group)  -> Log Analytics custom table (_CL)
#   AWS CloudWatch Agent             -> Azure Monitor Agent (VM extension)
#   AWS agent config (file paths)    -> Data Collection Rule (log_file source)
#
# Two log groups are mirrored as two custom tables:
#   /kurento-<tenant>-<purpose>/  -> kurento_<tenant>_<purpose>_CL
#       (kurento media server + coturn log files)
#   /recsvc-<tenant>-<purpose>/   -> recsvc_<tenant>_<purpose>_CL
#       (recsvc + archiver + verint connector + transcribe log files)
# ---------------------------------------------------------------------------

locals {
  # Custom Log Analytics table names must be alphanumeric/underscore and end in _CL.
  log_table_suffix   = replace("${var.tenant_id}_${var.infrastructure_purpose}", "-", "_")
  kurento_table_name = "kurento_${local.log_table_suffix}_CL"
  recsvc_table_name  = "recsvc_${local.log_table_suffix}_CL"

  kurento_stream = "Custom-${local.kurento_table_name}"
  recsvc_stream  = "Custom-${local.recsvc_table_name}"
}

# ---------------------------------------------------------------------------
# Log Analytics workspace (the "CloudWatch Logs" store)
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.resource_prefix}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_in_days

  tags = {
    Environment = var.infrastructure_purpose
    Tenant      = var.tenant_id
  }
}

# Data Collection Endpoint - required for custom text log collection via AMA.
resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "${var.resource_prefix}-dce"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Environment = var.infrastructure_purpose
    Tenant      = var.tenant_id
  }
}

# ---------------------------------------------------------------------------
# Custom tables (the equivalent of AWS CloudWatch log groups)
#
# Custom text-log tables ingested via DCR require the TimeGenerated and RawData
# columns. FilePath lets us tell apart the different services that share a table
# (the equivalent of AWS log streams within a log group).
# ---------------------------------------------------------------------------

resource "azapi_resource" "kurento_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  name      = local.kurento_table_name
  parent_id = azurerm_log_analytics_workspace.law.id

  body = {
    properties = {
      retentionInDays = var.log_retention_in_days
      schema = {
        name = local.kurento_table_name
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "RawData", type = "string" },
          { name = "Computer", type = "string" },
          { name = "FilePath", type = "string" },
        ]
      }
    }
  }
}

resource "azapi_resource" "recsvc_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  name      = local.recsvc_table_name
  parent_id = azurerm_log_analytics_workspace.law.id

  body = {
    properties = {
      retentionInDays = var.log_retention_in_days
      schema = {
        name = local.recsvc_table_name
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "RawData", type = "string" },
          { name = "Computer", type = "string" },
          { name = "FilePath", type = "string" },
        ]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Data Collection Rule - Kurento nodes
# Collects the kurento media server and coturn log files (+ syslog).
# ---------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "kurento" {
  name                        = "${var.resource_prefix}-kurento-dcr"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"

  destinations {
    log_analytics {
      name                  = "law-dest"
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
    }
  }

  stream_declaration {
    stream_name = local.kurento_stream
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "RawData"
      type = "string"
    }
    column {
      name = "Computer"
      type = "string"
    }
    column {
      name = "FilePath"
      type = "string"
    }
  }

  data_sources {
    log_file {
      name          = "kurento-app-logs"
      format        = "text"
      streams       = [local.kurento_stream]
      file_patterns = [var.kurento_service_log_file_path, var.coturn_service_log_file_path]
      settings {
        text {
          record_start_timestamp_format = "ISO 8601"
        }
      }
    }

    syslog {
      name           = "kurento-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["*"]
      log_levels     = ["*"]
    }
  }

  data_flow {
    streams       = [local.kurento_stream]
    destinations  = ["law-dest"]
    transform_kql = "source"
    output_stream = local.kurento_stream
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law-dest"]
  }

  depends_on = [azapi_resource.kurento_table]
}

# ---------------------------------------------------------------------------
# Data Collection Rule - Processing nodes
# Collects recsvc / archiver / verint connector / transcribe log files (+ syslog).
# ---------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "processing" {
  name                        = "${var.resource_prefix}-processing-dcr"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"

  destinations {
    log_analytics {
      name                  = "law-dest"
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
    }
  }

  stream_declaration {
    stream_name = local.recsvc_stream
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "RawData"
      type = "string"
    }
    column {
      name = "Computer"
      type = "string"
    }
    column {
      name = "FilePath"
      type = "string"
    }
  }

  data_sources {
    log_file {
      name    = "processing-app-logs"
      format  = "text"
      streams = [local.recsvc_stream]
      file_patterns = [
        var.recsvc_log_file_path,
        var.archiver_log_file_path,
        var.verint_connector_log_file_path,
        var.aws_transcribe_log_file_path,
      ]
      settings {
        text {
          record_start_timestamp_format = "ISO 8601"
        }
      }
    }

    syslog {
      name           = "processing-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["*"]
      log_levels     = ["*"]
    }
  }

  data_flow {
    streams       = [local.recsvc_stream]
    destinations  = ["law-dest"]
    transform_kql = "source"
    output_stream = local.recsvc_stream
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law-dest"]
  }

  depends_on = [azapi_resource.recsvc_table]
}

# ---------------------------------------------------------------------------
# Azure Monitor Agent (equivalent of the AWS CloudWatch agent install)
# ---------------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "ama_kurento" {
  count                      = local.vm_instance_count
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.kurento[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

resource "azurerm_virtual_machine_extension" "ama_processing" {
  count                      = local.vm_instance_count
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.processing[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

# ---------------------------------------------------------------------------
# RBAC: VM managed identity must publish to the DCR (portal does this automatically;
# Terraform requires an explicit role assignment).
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "kurento_dcr_metrics_publisher" {
  count                = local.vm_instance_count
  scope                = azurerm_monitor_data_collection_rule.kurento.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.kurento[count.index].identity[0].principal_id
}

resource "azurerm_role_assignment" "processing_dcr_metrics_publisher" {
  count                = local.vm_instance_count
  scope                = azurerm_monitor_data_collection_rule.processing.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.processing[count.index].identity[0].principal_id
}

# ---------------------------------------------------------------------------
# Associate each VM with its Data Collection Rule (DCE is already linked on the DCR itself).
# ---------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule_association" "kurento" {
  count                   = local.vm_instance_count
  name                    = "${var.resource_prefix}-kurento-dcra-${count.index + 1}"
  target_resource_id      = azurerm_linux_virtual_machine.kurento[count.index].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.kurento.id

  depends_on = [
    azurerm_virtual_machine_extension.ama_kurento,
    azurerm_role_assignment.kurento_dcr_metrics_publisher,
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "processing" {
  count                   = local.vm_instance_count
  name                    = "${var.resource_prefix}-processing-dcra-${count.index + 1}"
  target_resource_id      = azurerm_linux_virtual_machine.processing[count.index].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.processing.id

  depends_on = [
    azurerm_virtual_machine_extension.ama_processing,
    azurerm_role_assignment.processing_dcr_metrics_publisher,
  ]
}
