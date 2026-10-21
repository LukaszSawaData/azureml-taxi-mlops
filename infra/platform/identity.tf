# GitHub Actions logs in to Azure with OIDC (no secrets): one managed identity per environment.
resource "azurerm_user_assigned_identity" "github" {
  for_each            = var.environments
  name                = "id-${var.project}-${each.key}-github"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = merge(local.tags, { env = each.key })
}

data "github_user" "owner" {
  username = var.github_owner
}

data "github_repository" "repo" {
  full_name = "${var.github_owner}/${var.github_repo}"
}

locals {
  # GitHub sends the subject with numeric IDs: repo:<owner>@<id>/<repo>@<id>:...
  gh_subject = "repo:${var.github_owner}@${data.github_user.owner.id}/${var.github_repo}@${data.github_repository.repo.repo_id}"
  gh_issuer  = "https://token.actions.githubusercontent.com"

}

# Created one by one: parallel writes to one identity fail.
resource "azurerm_federated_identity_credential" "dev" {
  name      = "gh-env-dev"
  parent_id = azurerm_user_assigned_identity.github["dev"].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = local.gh_issuer
  subject   = "${local.gh_subject}:environment:dev"
}

resource "azurerm_federated_identity_credential" "prod" {
  name      = "gh-env-prod"
  parent_id = azurerm_user_assigned_identity.github["prod"].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = local.gh_issuer
  subject   = "${local.gh_subject}:environment:prod"
}

resource "azurerm_federated_identity_credential" "prod_model" {
  name       = "gh-env-prod-model"
  parent_id  = azurerm_user_assigned_identity.github["prod"].id
  audience   = ["api://AzureADTokenExchange"]
  issuer     = local.gh_issuer
  subject    = "${local.gh_subject}:environment:prod-model"
  depends_on = [azurerm_federated_identity_credential.prod]
}
