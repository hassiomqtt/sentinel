# Azure Functions Module - Remediation Functions

# Storage Account for Functions
resource "azurerm_storage_account" "functions" {
  name                     = lower(replace("${var.app_name}storage", "-", ""))
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false

  network_rules {
    default_action             = var.enable_vnet_integration ? "Deny" : "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.enable_vnet_integration ? [var.subnet_id] : []
  }

  tags = merge(
    var.tags,
    {
      Component = "Functions-Storage"
    }
  )
}

# App Service Plan (Elastic Premium for VNet integration)
resource "azurerm_service_plan" "functions" {
  name                = "${var.app_name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.sku_name

  tags = merge(
    var.tags,
    {
      Component = "Functions-Plan"
    }
  )
}

# Linux Function App
resource "azurerm_linux_function_app" "main" {
  name                       = var.app_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  site_config {
    always_on                              = true
    application_insights_connection_string = var.application_insights_connection_string
    application_insights_key               = var.application_insights_key

    application_stack {
      python_version = var.runtime_version
    }

    cors {
      allowed_origins = []
    }

    ftps_state             = "Disabled"
    http2_enabled          = true
    minimum_tls_version    = "1.2"
    use_32_bit_worker      = false
    vnet_route_all_enabled = var.enable_vnet_integration
  }

  app_settings = merge(
    var.app_settings,
    {
      FUNCTIONS_WORKER_RUNTIME       = var.runtime
      WEBSITE_RUN_FROM_PACKAGE       = "1"
      AzureWebJobsDisableHomepage    = "true"
      ENABLE_ORYX_BUILD              = "true"
      SCM_DO_BUILD_DURING_DEPLOYMENT = "true"

      # Python specific
      PYTHON_ENABLE_WORKER_EXTENSIONS    = "1"
      PYTHON_ISOLATE_WORKER_DEPENDENCIES = "1"

      # Storage
      AzureWebJobsStorage                      = azurerm_storage_account.functions.primary_connection_string
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.functions.primary_connection_string
      WEBSITE_CONTENTSHARE                     = lower(var.app_name)
    }
  )

  identity {
    type = "SystemAssigned"
  }

  # VNet Integration
  dynamic "virtual_network_subnet_id" {
    for_each = var.enable_vnet_integration ? [1] : []
    content {
      subnet_id = var.subnet_id
    }
  }

  https_only = true

  tags = merge(
    var.tags,
    {
      Component = "Functions-App"
    }
  )

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# Key Vault Access Policy for Function App
resource "azurerm_key_vault_access_policy" "functions" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_linux_function_app.main.identity[0].tenant_id
  object_id    = azurerm_linux_function_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "functions" {
  name                       = "${var.app_name}-diagnostics"
  target_resource_id         = azurerm_linux_function_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Application Insights Component Reference (passed from monitoring module)
# Function code structure (deployed separately):
# - credential-rotation/
#   - __init__.py (main function)
#   - function.json
# - access-control/
#   - __init__.py
#   - function.json
# - network-isolation/
#   - __init__.py
#   - function.json
# - threat-analysis/
#   - __init__.py
#   - function.json
# - shared/
#   - azure_clients.py
#   - config.py
#   - utils.py
