locals {
  me = data.azurerm_client_config.current.object_id

  role_assignments = merge([
    for env in keys(var.environments) : {
      # GitHub identity: works only inside its own workspace.
      "${env}-github-workspace" = {
        scope     = azurerm_machine_learning_workspace.this[env].id
        role      = "AzureML Data Scientist"
        principal = azurerm_user_assigned_identity.github[env].principal_id
      }
      # You: full access in dev, read-only in prod (prod changes only through GitHub).
      "${env}-me-workspace" = {
        scope     = azurerm_machine_learning_workspace.this[env].id
        role      = env == "prod" ? "Reader" : "AzureML Data Scientist"
        principal = local.me
      }
      # Training cluster identity: job outputs, images, secrets.
      "${env}-compute-storage" = {
        scope     = azurerm_storage_account.workspace[env].id
        role      = "Storage Blob Data Contributor"
        principal = azurerm_user_assigned_identity.compute[env].principal_id
      }
      "${env}-compute-acr" = {
        scope     = azurerm_container_registry.this.id
        role      = "AcrPull"
        principal = azurerm_user_assigned_identity.compute[env].principal_id
      }
      "${env}-compute-keyvault" = {
        scope     = azurerm_key_vault.this[env].id
        role      = "Key Vault Secrets User"
        principal = azurerm_user_assigned_identity.compute[env].principal_id
      }
    }
  ]...)
}

resource "azurerm_role_assignment" "this" {
  for_each             = local.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = each.value.principal
}
