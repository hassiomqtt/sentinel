# General Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project    = "Sentinel-Remediation"
    ManagedBy  = "Terraform"
    CostCenter = "Security"
  }
}

# Networking Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "function_subnet_prefix" {
  description = "Address prefix for Functions subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoint_subnet_prefix" {
  description = "Address prefix for private endpoints subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection plan"
  type        = bool
  default     = false
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for PaaS services"
  type        = bool
  default     = true
}

# Sentinel Configuration
variable "sentinel_workspace_name" {
  description = "Name of the Log Analytics workspace for Sentinel"
  type        = string
}

variable "sentinel_retention_days" {
  description = "Number of days to retain Sentinel data"
  type        = number
  default     = 90
  validation {
    condition     = var.sentinel_retention_days >= 30 && var.sentinel_retention_days <= 730
    error_message = "Retention days must be between 30 and 730."
  }
}

variable "sentinel_daily_quota_gb" {
  description = "Daily ingestion quota in GB"
  type        = number
  default     = 10
}

variable "enable_azure_activity_connector" {
  description = "Enable Azure Activity Logs connector"
  type        = bool
  default     = true
}

variable "enable_azure_ad_connector" {
  description = "Enable Azure AD connector"
  type        = bool
  default     = true
}

variable "enable_security_center_connector" {
  description = "Enable Microsoft Defender for Cloud connector"
  type        = bool
  default     = true
}

# Azure Functions Configuration
variable "functions_app_name" {
  description = "Name of the Azure Functions app"
  type        = string
}

variable "functions_runtime" {
  description = "Functions runtime"
  type        = string
  default     = "python"
}

variable "functions_runtime_version" {
  description = "Functions runtime version"
  type        = string
  default     = "3.11"
}

variable "functions_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "EP1" # Elastic Premium
}

# Key Vault Configuration
variable "admin_object_ids" {
  description = "Object IDs of users/groups to grant Key Vault admin access"
  type        = list(string)
  default     = []
}

# Application Settings
variable "enable_auto_remediation" {
  description = "Enable automated remediation"
  type        = bool
  default     = true
}

variable "threat_score_threshold" {
  description = "Threat score threshold for auto-remediation"
  type        = number
  default     = 70
  validation {
    condition     = var.threat_score_threshold >= 0 && var.threat_score_threshold <= 100
    error_message = "Threat score threshold must be between 0 and 100."
  }
}

# DevOps Integration
variable "devops_org_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = ""
}

variable "devops_project" {
  description = "Azure DevOps project name"
  type        = string
  default     = ""
}

# Notification Settings
variable "security_email" {
  description = "Email address for security alerts"
  type        = string
  default     = ""
}

variable "teams_webhook_uri" {
  description = "Microsoft Teams webhook URI"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key"
  type        = string
  default     = ""
  sensitive   = true
}

# Feature Flags
variable "enable_predictive_detection" {
  description = "Enable ML-based predictive threat detection"
  type        = bool
  default     = true
}

variable "enable_devops_integration" {
  description = "Enable DevOps pipeline integration"
  type        = bool
  default     = true
}

variable "enable_chaos_testing" {
  description = "Enable chaos engineering tests"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "enable_detailed_metrics" {
  description = "Enable detailed metrics collection"
  type        = bool
  default     = true
}
