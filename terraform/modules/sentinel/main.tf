# Sentinel Module - Log Analytics Workspace and Sentinel Configuration

# Generate UUIDs for automation rule names
resource "random_uuid" "credential_compromise_rule" {}
resource "random_uuid" "suspicious_access_rule" {}

resource "azurerm_log_analytics_workspace" "sentinel" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb

  tags = merge(
    var.tags,
    {
      Component = "Sentinel"
      Purpose   = "Security-Monitoring"
    }
  )
}

# Enable Sentinel on the workspace
resource "azurerm_log_analytics_solution" "sentinel" {
  solution_name         = "SecurityInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.sentinel.id
  workspace_name        = azurerm_log_analytics_workspace.sentinel.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }

  tags = var.tags
}

# Data Connectors
resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  count                      = var.enable_azure_ad ? 1 : 0
  name                       = "AzureActiveDirectory"
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
}

resource "azurerm_sentinel_data_connector_azure_security_center" "asc" {
  count                      = var.enable_security_center ? 1 : 0
  name                       = "AzureSecurityCenter"
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
}

resource "azurerm_sentinel_data_connector_microsoft_cloud_app_security" "mcas" {
  count                      = var.enable_mcas ? 1 : 0
  name                       = "MicrosoftCloudAppSecurity"
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
}

# Automation Rules for triggering Logic Apps
resource "azurerm_sentinel_automation_rule" "credential_compromise" {
  name                       = random_uuid.credential_compromise_rule.result
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
  display_name               = "Credential Compromise - Auto Remediation"
  order                      = 1
  enabled                    = true

  condition_json = jsonencode({
    clauses = [
      {
        conditionProperties = {
          propertyName   = "IncidentTitle"
          operator       = "Contains"
          propertyValues = ["Credential", "Password", "Authentication"]
        }
        conditionType = "Property"
      }
    ]
    operator = "And"
  })

  action_incident {
    order  = 1
    status = "Active"
  }
}

resource "azurerm_sentinel_automation_rule" "suspicious_access" {
  name                       = random_uuid.suspicious_access_rule.result
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
  display_name               = "Suspicious Access Pattern - Auto Remediation"
  order                      = 2
  enabled                    = true

  condition_json = jsonencode({
    clauses = [
      {
        conditionProperties = {
          propertyName   = "IncidentTitle"
          operator       = "Contains"
          propertyValues = ["Suspicious", "Anomalous", "Unusual"]
        }
        conditionType = "Property"
      }
    ]
    operator = "And"
  })

  action_incident {
    order  = 1
    status = "Active"
  }
}

# Analytics Rules (will be imported from KQL files)
resource "azurerm_sentinel_alert_rule_scheduled" "failed_login_spike" {
  name                       = "FailedLoginSpike"
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
  display_name               = "Spike in Failed Login Attempts"
  description                = "Detects abnormal increase in failed login attempts"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType != 0
    | summarize FailedAttempts = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 5m)
    | where FailedAttempts > 5
    | extend ThreatScore = FailedAttempts * 10
    | where ThreatScore > 50
  QUERY

  query_frequency     = "PT15M"
  query_period        = "PT1H"
  trigger_operator    = "GreaterThan"
  trigger_threshold   = 0
  suppression_enabled = false

  event_grouping {
    aggregation_method = "AlertPerResult"
  }

  incident {
    create_incident_enabled = true

    grouping {
      enabled                 = true
      lookback_duration       = "PT6H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }

  alert_details_override {
    display_name_format  = "Failed Login Spike: {{UserPrincipalName}}"
    description_format   = "Detected {{FailedAttempts}} failed attempts from {{IPAddress}}"
    severity_column_name = "ThreatScore"
    tactics_column_name  = "Tactic"
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "unusual_location_login" {
  name                       = "UnusualLocationLogin"
  log_analytics_workspace_id = azurerm_log_analytics_solution.sentinel.workspace_resource_id
  display_name               = "Login from Unusual Location"
  description                = "Detects login attempts from locations not seen in the past 30 days"
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    let historical_locations = SigninLogs
    | where TimeGenerated between (ago(14d) .. ago(1d))
    | where ResultType == 0
    | summarize by UserPrincipalName, Location;
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType == 0
    | join kind=leftanti (historical_locations) on UserPrincipalName, Location
    | extend ThreatScore = 60
  QUERY

  query_frequency     = "PT1H"
  query_period        = "P14D"
  trigger_operator    = "GreaterThan"
  trigger_threshold   = 0
  suppression_enabled = false

  event_grouping {
    aggregation_method = "AlertPerResult"
  }

  incident {
    create_incident_enabled = true

    grouping {
      enabled                 = true
      lookback_duration       = "PT12H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
}

# Watchlists for threat intelligence
resource "azurerm_sentinel_watchlist" "known_malicious_ips" {
  name                       = "KnownMaliciousIPs"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Known Malicious IP Addresses"
  description                = "List of IP addresses identified as malicious"
  item_search_key            = "IPAddress"
}

resource "azurerm_sentinel_watchlist" "privileged_accounts" {
  name                       = "PrivilegedAccounts"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Privileged User Accounts"
  description                = "List of accounts with elevated privileges requiring extra monitoring"
  item_search_key            = "UserPrincipalName"
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "sentinel" {
  name                       = "sentinel-diagnostics"
  target_resource_id         = azurerm_log_analytics_workspace.sentinel.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "Audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
