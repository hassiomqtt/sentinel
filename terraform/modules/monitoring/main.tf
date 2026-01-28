# Monitoring Module

resource "azurerm_application_insights" "main" {
  name                = "${var.environment}-appi"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "other"
  retention_in_days   = 90
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "security" {
  name                = "security-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "sec-alert"

  email_receiver {
    name          = "security-team"
    email_address = var.alert_email
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "high_threat_score" {
  count               = var.enable_mttr_dashboard ? 1 : 0
  name                = "high-threat-score-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.log_analytics_workspace_id]
  description         = "Alert when threat score exceeds threshold"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.OperationalInsights/workspaces"
    metric_name      = "Average_CounterValue"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 70
  }

  action {
    action_group_id = azurerm_monitor_action_group.security.id
  }

  tags = var.tags
}

## Variables
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "enable_mttr_dashboard" { type = bool; default = true }
variable "enable_cost_analysis" { type = bool; default = true }
variable "alert_email" { type = string }
variable "tags" { type = map(string); default = {} }

## Outputs
output "application_insights_id" { value = azurerm_application_insights.main.id }
output "application_insights_name" { value = azurerm_application_insights.main.name }
output "application_insights_instrumentation_key" { value = azurerm_application_insights.main.instrumentation_key; sensitive = true }
output "application_insights_connection_string" { value = azurerm_application_insights.main.connection_string; sensitive = true }
