locals {
  region                 = "us-west1"
  zone                   = "us-west1-a"
  project_id             = "<project-id>"
  auth                   = file("~/.config/gcloud/application_default_credentials.json")
  instance_ssh_key_pub   = "~/.ssh/id_ed25519_cl.pub"
  instance_bastion_image = "ubuntu-os-cloud/ubuntu-2004-lts"
  instance_sensor_image  = "alma-8-20240516193720"
  subnetwork_mgmt_cidr   = "10.129.0.0/24"
  subnetwork_mon_cidr    = "10.3.0.0/24"
  subnetwork_mon_gateway = "10.3.0.1"
  license_key            = file("~/corelight-license.txt")
  community_string       = "managedPassword!"
  fleet_token            = "b1cd099ff22ed8a41abc63929d1db126"
  fleet_url              = "https://fleet.example.com:1443/fleet/v1/internal/softsensor/websocket"
}

####################################################################################################
# Configure the provider
####################################################################################################

provider "google" {
  project     = local.project_id
  credentials = local.auth
  region      = local.region
  zone        = local.zone
}

####################################################################################################
# Create a VPC
####################################################################################################

# firewall

# allow ssh traffic to mgmt (default is inbound)
resource "google_compute_firewall" "allow_ssh_to_mgmt" {
  name      = "corelight-allow-ssh-inbound-to-mgmt"
  direction = "INGRESS"
  network   = google_compute_network.mgmt.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

# allow internal SSH traffic in mgmt network
resource "google_compute_firewall" "allow_internal" {
  name      = "corelight-allow-internal"
  direction = "INGRESS"
  network   = google_compute_network.mgmt.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [local.subnetwork_mgmt_cidr]
  target_tags   = ["allow-ssh"]
}

# nat

resource "google_compute_router" "mgmt_router" {
  name    = "corelight-mgmt-router"
  region  = local.region
  network = google_compute_network.mgmt.name
}

resource "google_compute_router_nat" "mon_nat" {
  name                               = "corelight-mgmt-nat"
  router                             = google_compute_router.mgmt_router.name
  region                             = local.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# network

resource "google_compute_network" "mgmt" {
  name                    = "corelight-mgmt"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false
}

resource "google_compute_network" "prod" {
  name                    = "corelight-prod"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mgmt_subnet" {
  name          = "corelight-subnet"
  ip_cidr_range = local.subnetwork_mgmt_cidr
  network       = google_compute_network.mgmt.name
  region        = local.region
}

resource "google_compute_subnetwork" "mon_subnet" {
  name          = "corelight-mon-subnet"
  ip_cidr_range = local.subnetwork_mon_cidr
  network       = google_compute_network.prod.name
  region        = local.region
}

####################################################################################################
# Create a Bastion
####################################################################################################

module "custom_bastion" {
  source = "../../modules/bastion"

  zone                 = local.zone
  network_mgmt_name    = google_compute_network.mgmt.name
  subnetwork_mgmt_name = google_compute_subnetwork.mgmt_subnet.name
  instance_ssh_key_pub = local.instance_ssh_key_pub
  image                = local.instance_bastion_image
}

####################################################################################################
# Create Sensor Managed Instance Group
####################################################################################################

module "sensor" {
  source = "../.."

  region                 = local.region
  zone                   = local.zone
  network_mgmt_name      = google_compute_network.mgmt.name
  subnetwork_mgmt_name   = google_compute_subnetwork.mgmt_subnet.name
  subnetwork_mgmt_cidr   = local.subnetwork_mgmt_cidr
  network_prod_name      = google_compute_network.prod.name
  subnetwork_mon_name    = google_compute_subnetwork.mon_subnet.name
  subnetwork_mon_cidr    = local.subnetwork_mon_cidr
  subnetwork_mon_gateway = local.subnetwork_mon_gateway
  instance_ssh_key_pub   = local.instance_ssh_key_pub
  image                  = local.instance_sensor_image
  license_key            = local.license_key
  community_string       = local.community_string
  fleet_token            = local.fleet_token
  fleet_url              = local.fleet_url
}
