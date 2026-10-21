# Data asset = a named, versioned pointer to the public NYC taxi file.
# azurerm has no data-asset resource, so azapi calls the ARM API directly.
resource "azapi_resource" "taxi_data" {
  for_each  = var.environments
  type      = "Microsoft.MachineLearningServices/workspaces/data@2024-10-01"
  name      = "nyc-taxi-green-2016-01"
  parent_id = azurerm_machine_learning_workspace.this[each.key].id
  body = {
    properties = {
      dataType    = "uri_file"
      description = "NYC green taxi trips, January 2016 (Azure Open Datasets)."
    }
  }
}

resource "azapi_resource" "taxi_data_v1" {
  for_each  = var.environments
  type      = "Microsoft.MachineLearningServices/workspaces/data/versions@2024-10-01"
  name      = "1"
  parent_id = azapi_resource.taxi_data[each.key].id
  body = {
    properties = {
      dataType = "uri_file"
      dataUri  = var.taxi_data_url
      tags     = { source = "Azure Open Datasets", dataset = "nyctlc/green" }
    }
  }
}
