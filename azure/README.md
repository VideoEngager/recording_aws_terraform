# Recording Infrastructure Deployment — Azure

## Basic info

This directory deploys the recording infrastructure on **Microsoft Azure**, mirroring the AWS deployment (see the [repo root README](../README.md)) using equivalent Azure services:

| AWS building block                 | Azure equivalent                                            |
| ----------------------------------- | ------------------------------------------------------------ |
| Application Load Balancer (ALB)     | Application Gateway (L7, `Standard_v2`)                      |
| Kurento Worker (EC2)                | `azurerm_linux_virtual_machine` (kurento)                    |
| Processing Worker (EC2)             | `azurerm_linux_virtual_machine` (processing)                 |
| EFS                                 | Azure Files (`azurerm_storage_account` + `azurerm_storage_share`) |
| VPC                                 | Virtual Network (VNet) + Subnets                              |
| NAT Gateway (processing egress)     | Azure NAT Gateway + Standard public IP                        |
| Security Groups                     | Network Security Groups (NSGs)                                |
| CloudWatch Logs / Agent             | Log Analytics Workspace + Azure Monitor Agent (AMA)           |
| AMI                                 | Azure Managed Image (looked up dynamically by tag in a shared image resource group) |

Both the Kurento and Processing VMs are provisioned from pre-baked Azure Managed Images (equivalent of AWS AMIs), stored in a shared image resource group (`image_rg_name`, default `recording-amis`) and selected dynamically by name prefix + `Version` tag.

## Prerequisites

1. **Terraform** installed (`~> 1.x`). [Installation guide](https://learn.hashicorp.com/terraform/getting-started/install.html).
2. **Azure CLI** installed and authenticated against the target subscription:

   ```bash
   az login
   az account set --subscription "<subscription-id-or-name>"
   ```

   The `azurerm` and `azapi` providers use your Azure CLI session for authentication by default.
3. **OpenSSL** installed locally (used only once, to prepare the Application Gateway SSL certificate — see below). It ships by default on macOS/Linux; on Windows it is included with Git Bash, or can be installed separately.
4. Access to the shared image resource group (default `recording-amis`) containing the `kurento-prod-image-*` and `processing-prod-image-*` managed images that this configuration looks up automatically.

## Application Gateway SSL certificate (`appgatewaycert.pfx`)

When `use_ssl_for_app_gateway = true` (the default), the Application Gateway listeners for the `kurento` and `processing` backends terminate TLS using a certificate loaded from a **PFX (PKCS#12)** file named `appgatewaycert.pfx`, expected next to the Terraform files in this directory (see `app-gateway.tf`):

```hcl
dynamic "ssl_certificate" {
  for_each = var.use_ssl_for_app_gateway ? { (local.appgw_cert_name) = true } : {}
  content {
    name     = ssl_certificate.key
    data     = filebase64("${path.module}/appgatewaycert.pfx")
    password = var.app_gateway_cert_password
  }
}
```

Azure Application Gateway requires the certificate in `.pfx` format, whereas certificates issued/exported from AWS (e.g. AWS Certificate Manager exports, or any CA-issued cert bundle) are typically provided as separate PEM files:

* `private_key.txt` — the private key
* `certificate.txt` — the leaf/end-entity certificate
* `certificate_chain.txt` — the intermediate/root CA chain

### Converting the AWS-exported PEM files to a PFX file

Run the following `openssl` command to bundle those three files into the `.pfx` file that Terraform expects:

```bash
openssl pkcs12 -export -out appgatewaycert.pfx -inkey private_key.txt -in certificate.txt -certfile certificate_chain.txt
```

* `-out appgatewaycert.pfx` — the resulting PFX file.
* `-inkey private_key.txt` — the private key that matches the certificate.
* `-in certificate.txt` — the certificate itself.
* `-certfile certificate_chain.txt` — the CA chain, bundled alongside the certificate so Application Gateway can present a complete chain to clients.

When prompted, set an **export password** — this is the password you must put in the `app_gateway_cert_password` Terraform variable (default is the placeholder `1234`; **change this for any real deployment**, ideally passing it via `TF_VAR_app_gateway_cert_password` or a `.tfvars` file that is not committed to git).


> If you don't need HTTPS on the Application Gateway listeners, set `use_ssl_for_app_gateway = false` and the `.pfx` file / password are not required.

## Configuration

Key variables (see `variable.tf` for the full list and defaults):

| Variable | Purpose |
| --- | --- |
| `resource_prefix` | Prefix applied to all created resource names. |
| `location` | Azure region to deploy into (default `germanywestcentral`). |
| `image_rg_name` | Resource group containing the shared Kurento/Processing managed images. |
| `image_tag_version` | `Version` tag used to select the images (also tagged on the created VMs). |
| `kurento_image_resource_id` | Shared Gallery Resource ID of the Kurento image to use. If empty, the latest image with the specified version will be used. |
| `processing_image_resource_id` | Shared Gallery Resource ID of the Processing image to use. If empty, the latest image with the specified version will be used. |
| `kurento_vm_size` | VM SKU for the Kurento instances. |
| `processing_vm_size` | VM SKU for the Processing instances. |
| `kurento_node_count` | Scaling unit for Kurento instances (default `1`). In regions with 2 availability zones, total instances = `kurento_node_count * 2` (odd instance numbers in zone A, even in zone B); otherwise total instances = `kurento_node_count`. |
| `processing_node_count` | Scaling unit for Processing instances (default `1`). In regions with 2 availability zones, total instances = `processing_node_count * 2` (odd instance numbers in zone A, even in zone B); otherwise total instances = `processing_node_count`. |
| `use_ssl_for_app_gateway` | Enables HTTPS listeners on the Application Gateway using `appgatewaycert.pfx`. |
| `app_gateway_cert_password` | Password protecting `appgatewaycert.pfx`. |
| `appgw_allowed_cidrs` | List of source CIDR blocks allowed inbound to the Application Gateway listener ports (kurento, processing, and any enabled add-on services). Defaults to `["0.0.0.0/0"]` (open to the internet) — restrict this to known `/32` client IPs or specific subnet ranges for any real deployment to reduce exposure. |
| `ssh_allowed_cidrs` | List of source IP addresses/CIDR blocks allowed to SSH (TCP/22) into the Kurento and Processing VMs. Defaults to `["*"]` (open to anyone); set to an empty list `[]` to disable SSH access entirely. |
| `use_nat_gw` | If `true`, processing nodes are placed in **private subnets with private IPs only**; outbound internet goes through Azure NAT Gateway(s). In regions with multiple availability zones, one private subnet + zonal NAT Gateway is created per zone and processing VMs stay spread across those zones (same odd/even zone placement as without NAT). If `false` (default), processing nodes stay in the public subnet with public IPs. Kurento nodes always remain in the public subnet with public IPs. |
| `use_archiver_service` / `use_verint_connector_service` / `use_aws_transcribe_service` | Optional processing add-on services. |
| `genesys_webdav_server_url` / `genesys_username` / `genesys_password` | Genesys WebDAV integration settings. |
| `reporter_host` / `reporter_path` | RecAPI endpoint used by the processing service. |
| `tenant_id` / `infrastructure_purpose` | Naming for Log Analytics custom tables (mirrors AWS CloudWatch log group naming). |
| `log_retention_in_days` | Log Analytics retention period. |

Set overrides either via a `*.auto.tfvars` file in this directory or via `TF_VAR_<name>` environment variables (recommended for secrets like `app_gateway_cert_password`, `genesys_password`).

## Step-by-step, first-time deployment

1. Confirm the prerequisites above are satisfied (Terraform, Azure CLI logged in, `appgatewaycert.pfx` present if using SSL).

2. From this (`azure`) directory, initialize Terraform:

   ```bash
   terraform init
   ```

3. Review the deployment plan:

   ```bash
   terraform plan
   ```

4. If the plan looks correct, apply it:

   ```bash
   terraform apply
   ```

5. Once complete, fetch the public entry point:

   ```bash
   terraform output appgw_public_ip
   terraform output appgw_fqdn
   ```

## Outputs

| Output | Description |
| --- | --- |
| `appgw_public_ip` | Public IP of the Application Gateway frontend. |
| `appgw_fqdn` | FQDN of the Application Gateway public IP. |
| `nat_gateway_public_ip` | List of public IPs of the processing NAT Gateway(s) when `use_nat_gw = true` (one per availability zone); otherwise empty. |
| `kurento_public_ips` | Public IP addresses of all kurento VMs. |
| `processing_public_ips` | Public IP addresses of all processing VMs when `use_nat_gw = false`; empty when NAT Gateway is enabled. |
| `log_analytics_workspace_id` / `log_analytics_workspace_name` | Log Analytics workspace collecting instance logs. |
| `kurento_log_table_name` | Custom Log Analytics table with kurento + coturn logs (query via KQL). |
| `processing_log_table_name` | Custom Log Analytics table with recsvc/archiver/verint/transcribe logs (query via KQL). |

## Update procedure

When you need to update an existing deployment:

1. Make sure `terraform.tfstate` (or your configured remote state) is available in this directory.
2. Review and apply changes:

   ```bash
   terraform plan
   terraform apply
   ```

3. To force-replace a specific VM (e.g. to pick up a newer managed image after bumping `image_tag_version`):

   ```bash
   terraform plan -replace=azurerm_linux_virtual_machine.kurento[0]
   terraform apply -replace=azurerm_linux_virtual_machine.kurento[0]
   ```

   Adjust the index (`[0]`, `[1]`, ...) and resource (`kurento` / `processing`) based on `local.kurento_instance_count` / `local.processing_instance_count` (in regions with availability zones, `<role>_node_count * 2`; otherwise `<role>_node_count` instances).

## Monitoring

Logs from the Kurento (kurento media server, coturn) and Processing (recsvc, archiver, verint connector, transcribe) services, plus VM syslog, are collected by the **Azure Monitor Agent** and shipped to a **Log Analytics Workspace** via Data Collection Rules — this is the Azure equivalent of the AWS CloudWatch Logs/Agent setup. Query the custom tables (`kurento_<tenant>_<purpose>_CL` and `recsvc_<tenant>_<purpose>_CL`) from the Log Analytics workspace using KQL.
