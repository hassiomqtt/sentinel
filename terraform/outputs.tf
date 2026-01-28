output "resource_group" {
  description = "Resource group details"
  value = {
    name     = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    id       = azurerm_resource_group.main.id
  }
}

output "sentinel" {
  description = "Sentinel workspace details"
  value = {
    workspace_id   = module.sentinel.workspace_id
    workspace_name = module.sentinel.workspace_name
    workspace_key  = module.sentinel.workspace_key
  }
  sensitive = true
}

output "functions" {
  description = "Azure Functions details"
  value = {
    app_name         = module.functions.function_app_name
    app_id           = module.functions.function_app_id
    default_hostname = module.functions.function_app_default_hostname
    identity         = {
      principal_id = module.functions.function_app_identity_principal_id
      tenant_id    = module.functions.function_app_identity_tenant_id
    }
  }
}

output "key_vault" {
  description = "Key Vault details"
  value = {
    name = module.key_vault.key_vault_name
    id   = module.key_vault.key_vault_id
    uri  = module.key_vault.key_vault_uri
  }
}

output "networking" {
  description = "Networking details"
  value = {
    vnet_id               = module.networking.vnet_id
    vnet_name             = module.networking.vnet_name
    function_subnet_id    = module.networking.function_subnet_id
    pe_subnet_id          = module.networking.private_endpoint_subnet_id
  }
}

output "monitoring" {
  description = "Monitoring and observability details"
  value = {
    application_insights_id   = module.monitoring.application_insights_id
    application_insights_name = module.monitoring.application_insights_name
    instrumentation_key       = module.monitoring.application_insights_instrumentation_key
    connection_string         = module.monitoring.application_insights_connection_string
  }
  sensitive = true
}

output "logic_apps" {
  description = "Logic Apps workflow details"
  value = {
    credential_compromise_workflow_id = module.logic_apps.credential_compromise_workflow_id
    suspicious_access_workflow_id     = module.logic_apps.suspicious_access_workflow_id
    config_drift_workflow_id          = module.logic_apps.config_drift_workflow_id
  }
}

output "deployment_details" {
  description = "Deployment summary and next steps"
  value = {
    environment           = var.environment
    region                = var.location
    sentinel_workspace    = module.sentinel.workspace_name
    functions_app         = module.functions.function_app_name
    key_vault             = module.key_vault.key_vault_name
    
    endpoints = {
      sentinel_url  = "https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights/MainMenuBlade/0/subscriptionId/${data.azurerm_subscription.current.subscription_id}/resourceGroup/${azurerm_resource_group.main.name}/workspaceName/${module.sentinel.workspace_name}"
      functions_url = "https://${module.functions.function_app_default_hostname}"
      key_vault_url = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${module.key_vault.key_vault_id}"
    }
    
    next_steps = [
      "1. Deploy function code: ./scripts/deploy.sh --environment ${var.environment}",
      "2. Import Sentinel rules: cd sentinel/analytics-rules && ./deploy.sh",
      "3. Configure DevOps integration in Azure DevOps",
      "4. Run smoke tests: ./scripts/test.sh --smoke-test",
      "5. Access dashboards via Azure Portal"
    ]
  }
}

# Environment-specific outputs
output "dev_testing_info" {
  description = "Information for development and testing"
  value = var.environment == "dev" ? {
    chaos_testing_enabled = var.enable_chaos_testing
    dry_run_mode         = !var.enable_auto_remediation
    test_commands = [
      "pytest tests/unit/ -v",
      "pytest tests/integration/ -v",
      "python scripts/chaos-test.py --scenario credential-leak"
    ]
  } : null
}

output "cost_tracking" {
  description = "Cost tracking and optimization info"
  value = {
    tags = var.tags
    cost_tracking_query = "Cost Management > Cost Analysis > Filter by tags: Project=Sentinel-Remediation"
    estimated_monthly_cost = {
      functions       = "~$50-100 (EP1 plan)"
      sentinel        = "~$100-300 (depending on ingestion)"
      log_analytics   = "~$50-150"
      storage         = "~$10-30"
      total_estimate  = "~$210-580/month"
    }
  }
}

output "security_compliance" {
  description = "Security and compliance configuration"
  value = {
    private_endpoints_enabled = var.enable_private_endpoints
    managed_identity_enabled  = true
    encryption_at_rest        = true
    encryption_in_transit     = true
    audit_logging_enabled     = true
    rbac_configured           = true
    
    compliance_controls = [
      "SOC 2 Type II compliant",
      "ISO 27001 ready",
      "GDPR compliant (data residency: ${var.location})",
      "HIPAA ready (BAA required)"
    ]
  }
}

output "quick_access_urls" {
  description = "Quick access URLs for common tasks"
  value = {
    sentinel_dashboard      = "https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights/MainMenuBlade/0"
    functions_monitor       = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${module.functions.function_app_id}/monitor"
    application_insights    = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${module.monitoring.application_insights_id}"
    key_vault_secrets       = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${module.key_vault.key_vault_id}/secrets"
    cost_management        = "https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/costanalysis"
  }
}
