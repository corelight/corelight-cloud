locals {
  # Common Configuration
  aws_region        = "<aws_region>" 
  vpc_id            = "<vpc_id>"
  aws_key_pair_name = "<aws_key_pair_name>"

  # Fleet Configuration
  public_subnets    = ["<subnet-1>", "<subnet-2>"]
  private_subnet    = "<subnet-3>"
  route53_zone_name = "<route53_zone_name>"
  subdomain         = "<subdomain>"
  certificate_arn   = "<certificate_arn>"

  # Fleet Authentication
  community_string               = "corelight-community"
  fleet_username                 = "admin"
  fleet_password                 = "asdf1234"
  fleet_api_password             = "asdf1234"
  fleet_certificate_file_path    = "/path/to/certificate.pem"
  fleet_sensor_license_file_path = "/path/to/license.txt"

  # Fleet Optional Configuration (with defaults)
  alb_security_group_id              = null
  instance_security_group_id         = null
  alb_https_ingress_cidr_blocks      = ["0.0.0.0/0"]
  alb_api_ingress_cidr_blocks        = ["0.0.0.0/0"]
  admin_cidr_blocks                  = []
  aws_ami_owner                      = "099720109477"
  aws_ami_name                       = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  aws_ami_user                       = "ubuntu"
  aws_ec2_size                       = "t3.large"
  aws_volume_size                    = 50
  fleet_version                      = "28.2.2"
  radius_enable                      = false
  radius_address                     = ""
  radius_shared_secret               = ""
  fleet_instance_name                = "corelight-fleet"
  fleet_alb_name                     = "corelight-fleet-alb"
  fleet_lb_target_group_name         = "corelight-fleet-tg"
  fleet_alb_security_group_name      = "corelight-fleet-alb-security-group"
  fleet_instance_security_group_name = "corelight-fleet-instance-security-group"

  # Sensor Configuration
  sensor_instance_name    = "terraform-corelight-sensor"
  corelight_sensor_ami_id = "ami-09c608170bbd4b27e" # Example default AMI ID
  management_subnet_id    = "<management_subnet_id>"
  monitoring_subnet_id    = "<monitoring_subnet_id>"

  # Security Configuration
  ssh_allow_cidrs    = ["0.0.0.0/0"]
  mirror_allow_cidrs = ["0.0.0.0/0"]

  # Instance Configuration
  associate_public_ip_address = false

  # Sensor Optional Configuration (with defaults)
  custom_sensor_user_data                      = ""
  sensor_instance_name_default                 = "corelight-sensor"
  management_network_interface_name            = "corelight-sensor-nic"
  monitoring_network_interface_name            = "corelight-sensor-nic"
  instance_type                                = "c5.2xlarge"
  ebs_volume_size                              = 500
  sensor_management_security_group_name        = "corelight-management-sg"
  sensor_management_security_group_description = "Security group for the sensor which allows ssh"
  sensor_monitoring_security_group_name        = "corelight-management-sg"
  sensor_monitoring_security_group_description = "Security group for the sensor which allows ssh"
  iam_instance_profile_name                    = "corelight-sensor-iam-instance-profile"

  cloud_enrichment_config = {
    bucket_name   = ""
    bucket_region = ""
  }

  tags = {}

  # Computed Values
  fleet_ssl_name = "${local.subdomain}.${local.route53_zone_name}"
  fleet_url      = "https://${local.subdomain}.${local.route53_zone_name}/fleet/v1"
  fleet_api_url  = "https://${local.subdomain}.${local.route53_zone_name}:1443/fleet/v1/internal/softsensor/websocket"

  fleet_config = {
    token           = data.external.fleet_token.result.token
    url             = local.fleet_api_url
    server_ssl_name = local.fleet_ssl_name
    http_proxy      = ""
    https_proxy     = ""
    no_proxy        = ""
  }
}


module "corelight_fleet" {
  source = "github.com/corelight/terraform-aws-fleet"

  # Networking
  vpc_id            = local.vpc_id
  public_subnets    = local.public_subnets
  private_subnet    = local.private_subnet
  route53_zone_name = local.route53_zone_name
  subdomain         = local.subdomain
  certificate_arn   = local.certificate_arn

  # Optional networking
  alb_security_group_id         = local.alb_security_group_id
  instance_security_group_id    = local.instance_security_group_id
  alb_https_ingress_cidr_blocks = local.alb_https_ingress_cidr_blocks
  alb_api_ingress_cidr_blocks   = local.alb_api_ingress_cidr_blocks
  admin_cidr_blocks             = local.admin_cidr_blocks

  # EC2 Deployment
  aws_region        = local.aws_region
  aws_key_pair_name = local.aws_key_pair_name
  aws_ami_owner     = local.aws_ami_owner
  aws_ami_name      = local.aws_ami_name
  aws_ami_user      = local.aws_ami_user
  aws_ec2_size      = local.aws_ec2_size
  aws_volume_size   = local.aws_volume_size

  # Fleet Configuration
  fleet_version                  = local.fleet_version
  community_string               = local.community_string
  fleet_username                 = local.fleet_username
  fleet_password                 = local.fleet_password
  fleet_api_password             = local.fleet_api_password
  fleet_certificate_file_path    = local.fleet_certificate_file_path
  fleet_sensor_license_file_path = local.fleet_sensor_license_file_path

  # RADIUS Configuration
  radius_enable        = local.radius_enable
  radius_address       = local.radius_address
  radius_shared_secret = local.radius_shared_secret

  # Naming
  fleet_instance_name                = local.fleet_instance_name
  fleet_alb_name                     = local.fleet_alb_name
  fleet_lb_target_group_name         = local.fleet_lb_target_group_name
  fleet_alb_security_group_name      = local.fleet_alb_security_group_name
  fleet_instance_security_group_name = local.fleet_instance_security_group_name
}

resource "null_resource" "fleet_delay" {
  depends_on = [module.corelight_fleet]

  provisioner "local-exec" {
    command = "sleep 60" # Wait for Fleet to be ready
  }
}

module "corelight_single_sensor" {
  source = "github.com/corelight/terraform-aws-single-sensor"

  depends_on = [null_resource.fleet_delay]

  # Core configuration
  region                  = local.aws_region
  corelight_sensor_ami_id = local.corelight_sensor_ami_id
  management_subnet_id    = local.management_subnet_id
  monitoring_subnet_id    = local.monitoring_subnet_id
  vpc_id                  = local.vpc_id
  aws_key_pair_name       = local.aws_key_pair_name

  # Security
  ssh_allow_cidrs    = local.ssh_allow_cidrs
  mirror_allow_cidrs = local.mirror_allow_cidrs

  # Instance configuration
  associate_public_ip_address = local.associate_public_ip_address
  custom_sensor_user_data     = local.custom_sensor_user_data
  instance_name               = local.sensor_instance_name
  instance_type               = local.instance_type
  ebs_volume_size             = local.ebs_volume_size

  # Network interfaces
  management_network_interface_name = local.management_network_interface_name
  monitoring_network_interface_name = local.monitoring_network_interface_name

  # Security groups
  management_security_group_name        = local.sensor_management_security_group_name
  management_security_group_description = local.sensor_management_security_group_description
  monitoring_security_group_name        = local.sensor_monitoring_security_group_name
  monitoring_security_group_description = local.sensor_monitoring_security_group_description

  # IAM and tags
  iam_instance_profile_name = local.iam_instance_profile_name
  tags                      = local.tags

  # Licensing and Fleet
  license_key_file_path   = local.fleet_sensor_license_file_path
  fleet_community_string  = local.community_string
  fleet_config            = local.fleet_config
  cloud_enrichment_config = local.cloud_enrichment_config
}