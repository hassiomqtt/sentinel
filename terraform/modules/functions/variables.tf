variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Name of the Function App"
  type        = string
}

variable "runtime" {
  description = "Functions runtime"
  type        = string
  default     = "python"
}

variable "runtime_version" {
  description = "Runtime version"
  type        = string
  default     = "3.11"
}

variable "sku_name" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "EP1"
}

variable "subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
  default     = ""
}

variable "enable_vnet_integration" {
  description = "Enable VNet integration"
  type        = bool
  default     = true
}

variable "key_vault_id" {
  description = "Key Vault ID for access policy"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  type        = string
}

variable "application_insights_key" {
  description = "Application Insights instrumentation key"
  type        = string
  sensitive   = true
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string"
  type        = string
  sensitive   = true
}

variable "app_settings" {
  description = "Additional app settings"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
