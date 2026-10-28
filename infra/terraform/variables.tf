variable "resource_group_name" {
  description = "Existing Azure resource group for the GameMiKle web application."
  type        = string
  default     = "rg-gamemikle-prod"
}

variable "location" {
  description = "Azure region for Azure Static Web Apps."
  type        = string
  default     = "westeurope"
}

variable "project_name" {
  description = "Short project name used to name the Static Web App."
  type        = string
  default     = "gamemikle"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name must be 3-20 lowercase letters, digits, or hyphens."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}

variable "sku_tier" {
  description = "Azure Static Web Apps SKU. Free is appropriate for the first release."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}
