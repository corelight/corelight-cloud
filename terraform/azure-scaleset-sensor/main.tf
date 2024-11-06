locals {
  subscription_id     = "<your subscription uuid>"
  resource_group_name = "corelight"
  location            = "eastus"
  license             = "<your corelight sensor license key>"
  tags = {
    terraform : true,
    purpose : "Corelight"
  }
  fleet_token = "b1cd099ff22ed8a41abc63929d1db126"
  fleet_url   = "https://fleet.example.com:1443/fleet/v1/internal/softsensor/websocket"
}

####################################################################################################
# Create a resource group for the corelight resources
####################################################################################################
resource "azurerm_resource_group" "sensor_rg" {
  location = local.location
  name     = local.resource_group_name

  tags = local.tags
}

####################################################################################################
# Get data on the existing vnet and create a subnet in that vnet for the sensor
####################################################################################################
data "azurerm_virtual_network" "existing_vnet" {
  name                = "<vnet name>"
  resource_group_name = "<vnet resource group>"
}

####################################################################################################
# Deploy the Sensor
####################################################################################################
module "sensor" {
  source = "../.."

  license_key                    = local.license
  location                       = local.location
  resource_group_name            = azurerm_resource_group.sensor_rg.name
  virtual_network_name           = data.azurerm_virtual_network.existing_vnet.name
  virtual_network_resource_group = "<vnet resource group>"
  virtual_network_address_space  = "<vnet address space (CIDR)>"
  corelight_sensor_image_id      = "<image resource id from Corelight>"
  community_string               = "<the community string (api string) often times referenced by Fleet>"
  fleet_token                    = local.fleet_token
  fleet_url                      = local.fleet_url
  sensor_ssh_public_key          = "<path to ssh public key>"

  # (Optional) Cloud Enrichment Variables
  enrichment_storage_account_name   = "<name of the enrichment storage account>"
  enrichment_storage_container_name = "<name of the enrichment container in the storage account>"
  tags                              = local.tags
}

####################################################################################################
# (Optional) Assign the VMSS identity access to the enrichment bucket if enabled
####################################################################################################
resource "azurerm_role_assignment" "enrichment_data_access" {
  principal_id         = module.sensor.sensor_identity_principal_id
  scope                = "<resource id of the enrichment storage account>"
  role_definition_name = "Storage Blob Data Reader"
}
