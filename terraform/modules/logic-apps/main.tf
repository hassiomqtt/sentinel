# Logic Apps Module

resource "azurerm_logic_app_workflow" "credential_compromise" {
  name                = "credential-compromise-remediation"
  location            = var.location
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  tags = merge(
    var.tags,
    {
      Component = "Logic-Apps"
      Purpose   = "Credential-Remediation"
    }
  )
}

resource "azurerm_logic_app_workflow" "suspicious_access" {
  name                = "suspicious-access-remediation"
  location            = var.location
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  tags = merge(
    var.tags,
    {
      Component = "Logic-Apps"
      Purpose   = "Access-Remediation"
    }
  )
}

resource "azurerm_logic_app_workflow" "config_drift" {
  name                = "config-drift-remediation"
  location            = var.location
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  tags = merge(
    var.tags,
    {
      Component = "Logic-Apps"
      Purpose   = "Config-Remediation"
    }
  )
}

## Variables
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "sentinel_workspace_id" {
  type = string
}

variable "functions_app_name" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "teams_webhook_uri" {
  type      = string
  default   = ""
  sensitive = true
}

variable "security_email" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

## Outputs
output "credential_compromise_workflow_id" { value = azurerm_logic_app_workflow.credential_compromise.id }
output "suspicious_access_workflow_id" { value = azurerm_logic_app_workflow.suspicious_access.id }
output "config_drift_workflow_id" { value = azurerm_logic_app_workflow.config_drift.id }
output "logic_app_identity_principal_id" { value = azurerm_logic_app_workflow.credential_compromise.identity[0].principal_id }
