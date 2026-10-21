variable "subscription_id" {
  type    = string
  default = "fa136590-6fc9-454b-98e8-b83b7d9583dd" # Azure for Students
}

variable "location" {
  type    = string
  default = "germanywestcentral"

  validation {
    # Azure for Students policy "Allowed resource deployment regions"
    condition     = contains(["germanywestcentral", "switzerlandnorth", "swedencentral", "polandcentral", "francecentral"], var.location)
    error_message = "Region not allowed by the subscription policy."
  }
}

variable "project" {
  type    = string
  default = "taxi"
}

# Per environment: how much data it trains on (dev small, prod bigger).
variable "environments" {
  type = map(object({ max_rows = number }))
  default = {
    dev  = { max_rows = 3000 }
    prod = { max_rows = 30000 }
  }
}

# Quota (Azure for Students): 6 vCPU per region, 4 per VM family.
# Training: Dv3 family (2 vCPU, scales to 0). Endpoints: DSv2 family (1 vCPU each, +20% reserve).
variable "compute_vm_size" {
  type    = string
  default = "Standard_D2_v3"
}

variable "compute_idle_timeout" {
  type    = string
  default = "PT2M"
}

variable "taxi_data_url" {
  type        = string
  description = "NYC green taxi, January 2016 (Azure Open Datasets, public, ~1.4M trips)."
  default     = "https://azureopendatastorage.blob.core.windows.net/nyctlc/green/puYear=2016/puMonth=1/part-00119-tid-4753095944193949832-fee7e113-666d-4114-9fcb-bcd3046479f3-2689-1.c000.snappy.parquet"
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "budget_amount" {
  type    = number
  default = 20
}

variable "budget_start_date" {
  type    = string
  default = "2026-10-01T00:00:00Z"
}
