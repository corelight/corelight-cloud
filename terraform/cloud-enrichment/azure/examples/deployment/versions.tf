terraform {
  required_version = ">=1.3.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.97.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}
