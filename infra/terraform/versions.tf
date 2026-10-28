terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # The state is stored in a private Azure Blob container.
  # The GitHub Actions workflow supplies the backend settings at init time.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
