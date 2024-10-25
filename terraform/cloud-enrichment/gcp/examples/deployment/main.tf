locals {
  organization_id    = "12345"
  custom_org_role_id = "corelight_enrichment_role"
  location           = "us-central1"
  zone               = "us-central1-a"
  folder_to_observe  = "54321"
  project_id         = "corelight-enrichment-project"
  service_account_id = "corelight-enrichment"

  labels = {
    terraform : true,
    example : true,
    purpose : "Corelight"
  }
}

provider "google" {
  project = local.project_id
  region  = local.location

  # Uncomment this if needed
  # user_project_override = true
}

####################################################################################################
# Set up the GCS bucket for enrichment data
####################################################################################################
resource "random_id" "bucket_nonce" {
  byte_length = 4
}

resource "google_storage_bucket" "enrichment_bucket" {
  location                 = local.location
  name                     = "corelight-enrichment-${random_id.bucket_nonce.hex}"
  public_access_prevention = "enforced"

  labels = local.labels
}

####################################################################################################
# Create the organizational role with access to enumerate folders and projects
####################################################################################################
module "custom_org_role" {
  source = "../../modules/org_iam"

  custom_org_role_id = local.custom_org_role_id
  organization_id    = local.organization_id
}

####################################################################################################
# Deploy Cloud Run service and create service account with proper permissions
# Replace relative source with "source = github.com/corelight/terraform-gcp-enrichment"
####################################################################################################
module "enrichment" {
  source = "../.."

  enrichment_bucket_name = google_storage_bucket.enrichment_bucket.name
  folder_id              = local.folder_to_observe
  project_id             = local.project_id
  zone                   = local.zone
  location               = local.location
  organization_role_id   = module.custom_org_role.custom_org_role_id
  service_account_id     = local.service_account_id

  labels = local.labels
}

