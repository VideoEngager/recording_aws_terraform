# -----------------------------------------------------------------------------
# 1. Automation Account & Managed Identity
# -----------------------------------------------------------------------------
resource "azurerm_automation_account" "kurento_recovery" {
  name                = "aa-kurento-recovery"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"

  # Enable System-Assigned Managed Identity
  identity {
    type = "SystemAssigned"
  }
}

# -----------------------------------------------------------------------------
# 2. RBAC Permissions
# -----------------------------------------------------------------------------
# The runbook needs to restart VMs
resource "azurerm_role_assignment" "automation_vm_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.kurento_recovery.identity[0].principal_id
}

# The runbook needs to read App Gateway health and query Network Interfaces
resource "azurerm_role_assignment" "automation_network_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_automation_account.kurento_recovery.identity[0].principal_id
}

# -----------------------------------------------------------------------------
# 3. Automation Runbook (PowerShell Script)
# -----------------------------------------------------------------------------
resource "azurerm_automation_runbook" "reboot_vm" {
  name                    = "Restart-UnhealthyAppGwBackend"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.kurento_recovery.name
  log_verbose             = true
  log_progress            = true
  description             = "Finds unhealthy App GW backend targets and reboots the corresponding VMs."
  runbook_type            = "PowerShell"

  content = <<-EOT
<#
.SYNOPSIS
Reboots an Azure VM by finding the unhealthy backend IP from an App Gateway alert using the Common Alert Schema.
#>
param (
    [Parameter(Mandatory=$false)]
    [object]$WebhookData
)

if ($WebhookData) {
    Write-Output "Webhook payload received. Starting execution..."
    
    # Parse the Webhook JSON
    $payload = ConvertFrom-Json -InputObject $WebhookData.RequestBody
    
    # Extract the Resource ID using the Common Alert Schema
    $resourceId = $payload.data.essentials.alertTargetIDs[0]

    if (-not $resourceId) {
        Write-Error "Could not find alertTargetIDs in the payload essentials."
        exit
    }

    Write-Output "Alert triggered for resource: $resourceId"

    # 1. Authenticate
    try {
        Disable-AzContextAutosave -Scope Process | Out-Null
        $AzureContext = (Connect-AzAccount -Identity).context
        Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext | Out-Null
        Write-Output "Successfully authenticated using Managed Identity."
    } catch {
        Write-Error "Failed to authenticate. Ensure the Managed Identity is enabled and has correct RBAC rights."
        exit
    }

    # 2. Extract App Gateway Info
    $resourceIdParts = $resourceId -split "/"
    if ($resourceIdParts[6] -eq "Microsoft.Network" -and $resourceIdParts[7] -eq "applicationGateways") {
        $rgName = $resourceIdParts[4]
        $appGwName = $resourceIdParts[8]
        
        Write-Output "Checking health for Application Gateway: $appGwName in RG: $rgName"
        
        # 3. Get App Gateway Backend Health
        $health = Get-AzApplicationGatewayBackendHealth -Name $appGwName -ResourceGroupName $rgName
        
        $unhealthyIps = @()
        foreach ($pool in $health.BackendAddressPools) {
            foreach ($server in $pool.BackendHttpSettingsCollection[0].Servers) {
                if ($server.Health -eq "Unhealthy") {
                    $unhealthyIps += $server.Address
                }
            }
        }

        if ($unhealthyIps.Count -eq 0) {
            Write-Output "No unhealthy backend servers detected at this exact moment. Exiting."
            exit
        }

        Write-Output "Found Unhealthy IPs: $($unhealthyIps -join ', ')"

        # 4. Map IPs to VMs and Restart
        $allNics = Get-AzNetworkInterface 
        
        foreach ($ip in $unhealthyIps) {
            $badNic = $allNics | Where-Object { $_.IpConfigurations.PrivateIpAddress -contains $ip }
            
            if ($badNic -and $badNic.VirtualMachine) {
                $vmId = $badNic.VirtualMachine.Id
                $vmIdParts = $vmId -split "/"
                $vmRg = $vmIdParts[4]
                $vmName = $vmIdParts[8]
                
                Write-Output "Matched IP $ip to VM: $vmName (RG: $vmRg). Issuing restart command..."
                
                # Removed the invalid -Force parameter here
                Restart-AzVM -ResourceGroupName $vmRg -Name $vmName -NoWait
                
                Write-Output "Restart command sent for VM $vmName."
            } else {
                Write-Output "Could not map IP $ip to an existing Virtual Machine NIC."
            }
        }
    } else {
        Write-Output "Alerted resource is not an Application Gateway. Detected type: $($resourceIdParts[6])/$($resourceIdParts[7])"
    }
} else {
    Write-Output "No WebhookData received. This runbook is intended to run via Azure Monitor Webhook."
}
EOT
}

# -----------------------------------------------------------------------------
# 4. Webhook for the Runbook
# -----------------------------------------------------------------------------
resource "azurerm_automation_webhook" "reboot_webhook" {
  name                    = "webhook-reboot-appgw-targets"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.kurento_recovery.name
  runbook_name            = azurerm_automation_runbook.reboot_vm.name
  enabled                 = true
  expiry_time             = "2035-12-31T00:00:00Z"
}

# -----------------------------------------------------------------------------
# 5. Action Group
# -----------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "reboot_action" {
  name                = "ag-reboot-appgw-targets"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "RebootVMs"

  automation_runbook_receiver {
    name                    = "trigger-reboot-runbook"
    automation_account_id   = azurerm_automation_account.kurento_recovery.id
    runbook_name            = azurerm_automation_runbook.reboot_vm.name
    webhook_resource_id     = azurerm_automation_webhook.reboot_webhook.id
    is_global_runbook       = false
    service_uri             = azurerm_automation_webhook.reboot_webhook.uri
    use_common_alert_schema = true
  }
}

# -----------------------------------------------------------------------------
# 6. Metric Alert Rule (Application Gateway Unhealthy Target)
# -----------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "kurento_health_alert" {
  name                = "alert-kurento-unhealthy-target"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_gateway.recording.id]
  description         = "Triggers when Kurento App Gateway backend pool has an unhealthy host."

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.reboot_action.id
  }
}
