terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration for state management
  backend "azurerm" {
    # Configure via backend.hcl or environment variables
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = "Sentinel-Remediation"
      ManagedBy   = "Terraform"
      DeployedBy  = data.azurerm_client_config.current.client_id
      DeployedAt  = timestamp()
    }
  )
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  resource_group_name            = azurerm_resource_group.main.name
  location                       = var.location
  environment                    = var.environment
  vnet_address_space             = var.vnet_address_space
  function_subnet_prefix         = var.function_subnet_prefix
  private_endpoint_subnet_prefix = var.private_endpoint_subnet_prefix
  enable_ddos_protection         = var.enable_ddos_protection

  tags = var.tags
}

# Key Vault Module
module "key_vault" {
  source = "./modules/key-vault"

  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  environment             = var.environment
  tenant_id               = data.azurerm_client_config.current.tenant_id
  enable_private_endpoint = var.enable_private_endpoints
  subnet_id               = module.networking.private_endpoint_subnet_id

  # Access policies
  admin_object_ids = var.admin_object_ids

  tags = var.tags
}

# Log Analytics Workspace for Sentinel
module "sentinel" {
  source = "./modules/sentinel"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  workspace_name      = var.sentinel_workspace_name
  retention_days      = var.sentinel_retention_days
  daily_quota_gb      = var.sentinel_daily_quota_gb

  # Data connectors
  enable_azure_activity  = var.enable_azure_activity_connector
  enable_azure_ad        = var.enable_azure_ad_connector
  enable_security_center = var.enable_security_center_connector

  tags = var.tags
}

# Azure Functions App
module "functions" {
  source = "./modules/functions"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  app_name            = var.functions_app_name
  runtime             = var.functions_runtime
  runtime_version     = var.functions_runtime_version

  # Networking
  subnet_id               = module.networking.function_subnet_id
  enable_vnet_integration = true

  # Configuration
  key_vault_id                           = module.key_vault.key_vault_id
  log_analytics_workspace_id             = module.sentinel.workspace_id
  application_insights_key               = module.monitoring.application_insights_instrumentation_key
  application_insights_connection_string = module.monitoring.application_insights_connection_string

  # App settings
  app_settings = {
    SENTINEL_WORKSPACE_ID           = module.sentinel.workspace_id
    SENTINEL_WORKSPACE_KEY          = "@Microsoft.KeyVault(SecretUri=${module.key_vault.key_vault_uri}secrets/sentinel-workspace-key)"
    KEY_VAULT_URI                   = module.key_vault.key_vault_uri
    DEVOPS_ORG_URL                  = var.devops_org_url
    DEVOPS_PROJECT                  = var.devops_project
    DEVOPS_PAT                      = "@Microsoft.KeyVault(SecretUri=${module.key_vault.key_vault_uri}secrets/devops-pat)"
    ENABLE_AUTO_REMEDIATION         = var.enable_auto_remediation
    THREAT_SCORE_THRESHOLD          = var.threat_score_threshold
    PYTHON_ENABLE_WORKER_EXTENSIONS = "1"
  }

  tags = var.tags

  depends_on = [
    module.key_vault,
    module.networking
  ]
}

# Logic Apps Module
module "logic_apps" {
  source = "./modules/logic-apps"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment

  # Integration
  sentinel_workspace_id = module.sentinel.workspace_id
  functions_app_name    = module.functions.function_app_name
  key_vault_id          = module.key_vault.key_vault_id

  # Notification settings
  teams_webhook_uri = var.teams_webhook_uri
  security_email    = var.security_email

  tags = var.tags

  depends_on = [
    module.sentinel,
    module.functions
  ]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  environment                = var.environment
  log_analytics_workspace_id = module.sentinel.workspace_id

  # Metrics and alerts
  enable_mttr_dashboard = true
  enable_cost_analysis  = true
  alert_email           = var.security_email

  tags = var.tags
}

# Role Assignments
resource "azurerm_role_assignment" "functions_sentinel_reader" {
  scope                = module.sentinel.workspace_id
  role_definition_name = "Microsoft Sentinel Reader"
  principal_id         = module.functions.function_app_identity_principal_id
}

resource "azurerm_role_assignment" "functions_sentinel_responder" {
  scope                = module.sentinel.workspace_id
  role_definition_name = "Microsoft Sentinel Responder"
  principal_id         = module.functions.function_app_identity_principal_id
}

resource "azurerm_role_assignment" "functions_key_vault" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.functions.function_app_identity_principal_id
}

resource "azurerm_role_assignment" "logic_apps_sentinel_contributor" {
  scope                = module.sentinel.workspace_id
  role_definition_name = "Microsoft Sentinel Contributor"
  principal_id         = module.logic_apps.logic_app_identity_principal_id
}

# Outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "sentinel_workspace_id" {
  description = "Log Analytics Workspace ID for Sentinel"
  value       = module.sentinel.workspace_id
}

output "sentinel_workspace_name" {
  description = "Name of the Sentinel workspace"
  value       = module.sentinel.workspace_name
}

output "functions_app_name" {
  description = "Name of the Azure Functions app"
  value       = module.functions.function_app_name
}

output "functions_app_url" {
  description = "Default hostname of the Functions app"
  value       = module.functions.function_app_default_hostname
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.key_vault_uri
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.monitoring.application_insights_instrumentation_key
  sensitive   = true
}

output "deployment_instructions" {
  description = "Next steps for deployment"
  value       = <<-EOT
    Deployment completed successfully!
    
    Next steps:
    1. Deploy function code: ./scripts/deploy.sh --environment ${var.environment}
    2. Configure Sentinel rules: cd sentinel/analytics-rules && terraform apply
    3. Test deployment: ./scripts/test.sh --smoke-test
    4. Access Sentinel: https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights
    
    Key resources:
    - Resource Group: ${azurerm_resource_group.main.name}
    - Sentinel Workspace: ${module.sentinel.workspace_name}
    - Functions App: ${module.functions.function_app_name}
    - Key Vault: ${module.key_vault.key_vault_name}
  EOT
}
