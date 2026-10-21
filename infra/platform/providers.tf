terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azapi   = { source = "Azure/azapi", version = "~> 2.13" }
    github  = { source = "integrations/github", version = "~> 6.13" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # Local state: run once by you (subscription Owner). No secrets in it - GitHub uses OIDC.
}

provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    machine_learning {
      purge_soft_deleted_workspace_on_destroy = true
    }
    resource_group {
      # App Insights creates "Failure Anomalies" alert rules outside of Terraform state
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

# Auth: GITHUB_TOKEN env var (e.g. GITHUB_TOKEN=$(gh auth token)).
provider "github" {
  owner = var.github_owner
}
