output "workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.sentinel.id
}

output "workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.sentinel.name
}

output "workspace_resource_id" {
  description = "Log Analytics Workspace resource ID"
  value       = azurerm_log_analytics_workspace.sentinel.id
}

output "workspace_key" {
  description = "Log Analytics Workspace primary key"
  value       = azurerm_log_analytics_workspace.sentinel.primary_shared_key
  sensitive   = true
}

output "workspace_customer_id" {
  description = "Log Analytics Workspace customer ID"
  value       = azurerm_log_analytics_workspace.sentinel.workspace_id
}
