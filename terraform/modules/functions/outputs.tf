output "function_app_id" {
  description = "Function App ID"
  value       = azurerm_linux_function_app.main.id
}

output "function_app_name" {
  description = "Function App name"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.main.default_hostname
}

output "function_app_identity_principal_id" {
  description = "Principal ID of the Function App managed identity"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}

output "function_app_identity_tenant_id" {
  description = "Tenant ID of the Function App managed identity"
  value       = azurerm_linux_function_app.main.identity[0].tenant_id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.functions.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.functions.id
}
