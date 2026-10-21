data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  tags   = { project = "azureml-taxi-mlops" }
}

# ---------- shared ----------

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project}-mlops"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.project}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Docker images for training environments and endpoints (built by Azure ML).
resource "azurerm_container_registry" "this" {
  name                = "acr${var.project}mlops${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# ---------- per environment (dev, prod): one workspace each = real isolation ----------

resource "azurerm_application_insights" "this" {
  for_each            = var.environments
  name                = "appi-${var.project}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = merge(local.tags, { env = each.key })
}

resource "azurerm_storage_account" "workspace" {
  for_each                        = var.environments
  name                            = "st${var.project}${each.key}${local.suffix}"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = merge(local.tags, { env = each.key })
}

resource "azurerm_key_vault" "this" {
  for_each                   = var.environments
  name                       = "kv-${var.project}-${each.key}-${local.suffix}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  tags                       = merge(local.tags, { env = each.key })
}

resource "azurerm_machine_learning_workspace" "this" {
  for_each                      = var.environments
  name                          = "aml-${var.project}-${each.key}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  application_insights_id       = azurerm_application_insights.this[each.key].id
  key_vault_id                  = azurerm_key_vault.this[each.key].id
  storage_account_id            = azurerm_storage_account.workspace[each.key].id
  container_registry_id         = azurerm_container_registry.this.id
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.tags, { env = each.key })
}

# Identity of the training cluster (writes job outputs, pulls images).
resource "azurerm_user_assigned_identity" "compute" {
  for_each            = var.environments
  name                = "id-${var.project}-${each.key}-compute"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = merge(local.tags, { env = each.key })
}

resource "azurerm_machine_learning_compute_cluster" "cpu" {
  for_each                      = var.environments
  name                          = "cpu-cluster"
  location                      = azurerm_resource_group.this.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.this[each.key].id
  vm_size                       = var.compute_vm_size
  vm_priority                   = "Dedicated"
  ssh_public_access_enabled     = false

  scale_settings {
    min_node_count                       = 0 # costs nothing while idle
    max_node_count                       = 1
    scale_down_nodes_after_idle_duration = var.compute_idle_timeout
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.compute[each.key].id]
  }

  tags       = merge(local.tags, { env = each.key })
  depends_on = [azurerm_role_assignment.this]
}
