# GitHub environments:
#   dev         - no approval
#   prod        - CODE gate: a human approves before prod trains (only from main)
#   prod-model  - MODEL gate: a human approves the new prod model before it goes on the endpoint
locals {
  gh_envs = {
    dev        = { azure_env = "dev", approval = false }
    prod       = { azure_env = "prod", approval = true }
    prod-model = { azure_env = "prod", approval = true }
  }
}

resource "github_repository_environment" "env" {
  for_each            = local.gh_envs
  repository          = var.github_repo
  environment         = each.key
  prevent_self_review = false

  dynamic "reviewers" {
    for_each = each.value.approval ? [1] : []
    content {
      users = [data.github_user.owner.id]
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = each.value.approval ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "main_only" {
  for_each       = { for k, v in local.gh_envs : k => v if v.approval }
  repository     = var.github_repo
  environment    = github_repository_environment.env[each.key].environment
  branch_pattern = "main"
}

# Not secrets: OIDC needs only IDs. Values per environment.
locals {
  gh_env_vars = merge([
    for gh_env, v in local.gh_envs : {
      "${gh_env}-AZURE_CLIENT_ID" = { env = gh_env, name = "AZURE_CLIENT_ID", value = azurerm_user_assigned_identity.github[v.azure_env].client_id }
      "${gh_env}-AML_WORKSPACE"   = { env = gh_env, name = "AML_WORKSPACE", value = azurerm_machine_learning_workspace.this[v.azure_env].name }
      "${gh_env}-MAX_ROWS"        = { env = gh_env, name = "MAX_ROWS", value = tostring(var.environments[v.azure_env].max_rows) }
      "${gh_env}-ENDPOINT_NAME"   = { env = gh_env, name = "ENDPOINT_NAME", value = "taxi-fare-${v.azure_env}-${local.suffix}" }
    }
  ]...)
}

resource "github_actions_environment_variable" "this" {
  for_each      = local.gh_env_vars
  repository    = var.github_repo
  environment   = github_repository_environment.env[each.value.env].environment
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_variable" "repo" {
  for_each = {
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = var.subscription_id
    AZURE_RESOURCE_GROUP  = azurerm_resource_group.this.name
  }
  repository    = var.github_repo
  variable_name = each.key
  value         = each.value
}
