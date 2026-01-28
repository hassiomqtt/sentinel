# Networking Module

resource "azurerm_virtual_network" "main" {
  name                = "${var.environment}-vnet"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "functions" {
  name                 = "functions-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.function_subnet_prefix]

  delegation {
    name = "functions-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_endpoint_subnet_prefix]
}

resource "azurerm_network_security_group" "functions" {
  name                = "functions-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "functions" {
  subnet_id                 = azurerm_subnet.functions.id
  network_security_group_id = azurerm_network_security_group.functions.id
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

variable "vnet_address_space" {
  type = list(string)
}

variable "function_subnet_prefix" {
  type = string
}

variable "private_endpoint_subnet_prefix" {
  type = string
}

variable "enable_ddos_protection" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

## Outputs
output "vnet_id" { value = azurerm_virtual_network.main.id }
output "vnet_name" { value = azurerm_virtual_network.main.name }
output "function_subnet_id" { value = azurerm_subnet.functions.id }
output "private_endpoint_subnet_id" { value = azurerm_subnet.private_endpoints.id }
