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

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain data"
  type        = number
  default     = 90
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = -1
}

variable "enable_azure_activity" {
  description = "Enable Azure Activity Logs connector"
  type        = bool
  default     = true
}

variable "enable_azure_ad" {
  description = "Enable Azure AD connector"
  type        = bool
  default     = true
}

variable "enable_security_center" {
  description = "Enable Microsoft Defender for Cloud connector"
  type        = bool
  default     = true
}

variable "enable_mcas" {
  description = "Enable Microsoft Cloud App Security connector"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
