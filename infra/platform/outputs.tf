output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "workspaces" {
  value = { for k, w in azurerm_machine_learning_workspace.this : k => w.name }
}

output "github_identities" {
  value = { for k, i in azurerm_user_assigned_identity.github : k => i.client_id }
}
