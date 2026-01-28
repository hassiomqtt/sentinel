# Provider Configuration
# =======================
# Provider blocks are defined in main.tf to avoid duplication.
# This file is kept for documentation purposes.
#
# The azurerm provider is configured with:
#   - key_vault: purge_soft_delete_on_destroy = false, recover_soft_deleted_key_vaults = true
#   - resource_group: prevent_deletion_if_contains_resources = false
#
# The azuread provider uses default configuration.
#
# To customize provider settings, modify the provider blocks in main.tf.
