# Key Vault Module

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                        = "kv-${var.environment}-${random_string.kv_suffix.result}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 90
  purge_protection_enabled    = var.environment == "prod"
  enable_rbac_authorization   = true

  network_acls {
    default_action             = var.enable_private_endpoint ? "Deny" : "Allow"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.enable_private_endpoint ? [var.subnet_id] : []
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${azurerm_key_vault.main.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_key_vault.main.name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "kv_admin" {
  for_each             = toset(var.admin_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
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

variable "tenant_id" {
  type = string
}

variable "enable_private_endpoint" {
  type    = bool
  default = true
}

variable "subnet_id" {
  type    = string
  default = ""
}

variable "admin_object_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

## Outputs
output "key_vault_id" { value = azurerm_key_vault.main.id }
output "key_vault_name" { value = azurerm_key_vault.main.name }
output "key_vault_uri" { value = azurerm_key_vault.main.vault_uri }
