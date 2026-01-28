# Provider versions are specified in main.tf terraform block
# This file contains provider-specific configurations

provider "azurerm" {
  features {
    # Key Vault
    key_vault {
      purge_soft_delete_on_destroy    = var.environment != "prod"
      recover_soft_deleted_key_vaults = true
    }

    # Resource Group
    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "prod"
    }

    # Log Analytics
    log_analytics_workspace {
      permanently_delete_on_destroy = var.environment != "prod"
    }

    # Application Insights
    application_insights {
      disable_generated_rule = false
    }

    # Virtual Machine (for scale sets if needed)
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = var.environment != "prod"
    }
  }

  # Optional: Set specific subscription
  # subscription_id = var.subscription_id
  # tenant_id       = var.tenant_id
}

provider "azuread" {
  # tenant_id = var.tenant_id
}
