locals {
  subscription_id     = "12345" # Your Azure Subscription ID (UUID)
  resource_group_name = "corelight"
  deployment_location = "eastus"
  tags = {
    terraform : true,
    example : true,
    purpose : "Corelight"
  }
}

data "azurerm_subscription" "subscription" {
  subscription_id = local.subscription_id
}

####################################################################################################
# There is only one system topic per Azure subscription. Create a new one or use the existing one
####################################################################################################
resource "azurerm_eventgrid_system_topic" "system_topic" {
  location               = "Global"
  name                   = "subscription-system-topic"
  resource_group_name    = azurerm_resource_group.corelight_resource_group.name
  source_arm_resource_id = data.azurerm_subscription.subscription.id
  topic_type             = "microsoft.resources.subscriptions"

  tags = local.tags
}

####################################################################################################
# Create a new resource group or re-use an existing one
####################################################################################################
resource "azurerm_resource_group" "corelight_resource_group" {
  name     = local.resource_group_name
  location = local.deployment_location

  tags = local.tags
}

####################################################################################################
# Create a new storage account and container to store the enrichment data or re-use an existing one
####################################################################################################
resource "azurerm_storage_account" "enrichment_data" {
  # Azure Storage account names must be globally unique and have character restrictions
  # https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#storage-account-name
  name                     = "corelightenrichment"
  resource_group_name      = azurerm_resource_group.corelight_resource_group.name
  location                 = local.deployment_location
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags = local.tags
}

resource "azurerm_storage_container" "enrichment_bucket" {
  name                 = "enrichment"
  storage_account_name = azurerm_storage_account.enrichment_data.name
}

####################################################################################################
# Deploy the Container App and its supporting infrastructure
# Replace relative source with "source = github.com/corelight/terraform-azure-enrichment"
####################################################################################################
module "enrichment" {
  source = "../.."

  resource_group_name                  = azurerm_resource_group.corelight_resource_group.name
  enrichment_storage_account           = azurerm_storage_account.enrichment_data.name
  enrichment_storage_account_container = azurerm_storage_container.enrichment_bucket.name
  event_grid_system_topic_name         = azurerm_eventgrid_system_topic.system_topic.name
  location                             = local.deployment_location
  subscription_id                      = local.subscription_id

  tags = local.tags
}
