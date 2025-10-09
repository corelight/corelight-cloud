locals {
  # Common Configuration
  aws_key_pair_name = "<aws key pair name>"

  # Fleet Configuration
  fleet_vpc_id      = "<vpc where fleet is deployed>"
  public_subnets    = ["<public subnet 1>", "<public subnet 2>"]
  private_subnet    = "<private subnet>"
  route53_zone_name = "<route53 zone name>"
  subdomain         = "<subdomain for fleet>"
  certificate_arn   = "<certificate arn for fleet>"

  # Fleet Authentication
  community_string               = "corelight-community"
  fleet_username                 = "admin"
  fleet_password                 = "asdf1234"
  fleet_certificate_file_path    = "path/to/certificate.pem"
  fleet_sensor_license_file_path = "path/to/license.txt"

  # Fleet Optional Configuration (with defaults)
  alb_security_group_id              = null
  instance_security_group_id         = null
  alb_https_ingress_cidr_blocks      = ["0.0.0.0/0"]
  alb_api_ingress_cidr_blocks        = ["0.0.0.0/0"]
  admin_cidr_blocks                  = ["0.0.0.0/0"]
  aws_ami_owner                      = "099720109477"
  aws_ami_name                       = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  aws_ami_user                       = "ubuntu"
  aws_ec2_size                       = "t3.large"
  aws_volume_size                    = 50
  fleet_version                      = "28.3.3"
  radius_enable                      = false
  radius_address                     = ""
  radius_shared_secret               = ""
  fleet_instance_name                = "corelight-fleet"
  fleet_alb_name                     = "corelight-fleet-alb"
  fleet_lb_target_group_name         = "corelight-fleet-tg"
  fleet_alb_security_group_name      = "corelight-fleet-alb-security-group"
  fleet_instance_security_group_name = "corelight-fleet-instance-security-group"

  # Sensor Configuration
  sensor_vpc_id           = "<vpc where sensor is deployed>"
  sensor_instance_name    = "terraform-corelight-sensor"
  corelight_sensor_ami_id = "ami-09c608170bbd4b27e" # Example default AMI ID
  management_subnet_id    = "<management subnet ID>"
  monitoring_subnet_id    = "<monitoring subnet ID>"

  # Instance Configuration
  associate_public_ip_address = false

  # Sensor Optional Configuration (with defaults)
  custom_sensor_user_data                      = ""
  management_interface_name                    = "corelight-sensor-nic-management"
  monitoring_interface_name                    = "corelight-sensor-nic-monitoring"
  instance_type                                = "c5.2xlarge"
  ebs_volume_size                              = 500
  sensor_management_security_group_name        = "corelight-management-security-group"
  sensor_management_security_group_description = "management security group for the sensor which allows ssh"
  sensor_monitoring_security_group_name        = "corelight-monitoring-security-group"
  sensor_monitoring_security_group_description = "monitoring security group for the sensor which allows ssh"

  # Computed Values
  fleet_server_ssl_name = "${local.subdomain}.${local.route53_zone_name}"
  fleet_base_url        = "https://${local.fleet_server_ssl_name}"
  fleet_url             = "${local.fleet_base_url}/fleet/v1"
  fleet_api_url         = "${local.fleet_base_url}:1443/fleet/v1/internal/softsensor/websocket"
  fleet_token           = data.external.fleet_token.result.token

}


module "corelight_fleet" {
  source = "github.com/corelight/terraform-aws-fleet"

  # Networking
  vpc_id            = local.fleet_vpc_id
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
    command = <<EOT
until curl -k -s -o /dev/null -w "%%{http_code}" "${local.fleet_base_url}" | grep -q "200"; do
  echo "Waiting for Fleet to be ready at ${local.fleet_base_url}..."
  sleep 5
done
EOT
  }
}

module "corelight_single_sensor" {
  source = "github.com/corelight/terraform-aws-single-sensor"

  depends_on = [null_resource.fleet_delay]

  # Core configuration
  ami_id                         = local.corelight_sensor_ami_id
  management_interface_subnet_id = local.management_subnet_id
  monitoring_interface_subnet_id = local.monitoring_subnet_id
  aws_key_pair_name              = local.aws_key_pair_name

  # Instance configuration
  management_security_group_vpc_id = local.sensor_vpc_id
  monitoring_security_group_vpc_id = local.sensor_vpc_id
  management_interface_public_ip   = local.associate_public_ip_address
  custom_sensor_user_data          = local.custom_sensor_user_data
  instance_name                    = local.sensor_instance_name
  instance_type                    = local.instance_type
  ebs_volume_size                  = local.ebs_volume_size

  # Network interfaces
  management_interface_name = local.management_interface_name
  monitoring_interface_name = local.monitoring_interface_name

  # Security groups
  management_security_group_name        = local.sensor_management_security_group_name
  management_security_group_description = local.sensor_management_security_group_description
  monitoring_security_group_name        = local.sensor_monitoring_security_group_name
  monitoring_security_group_description = local.sensor_monitoring_security_group_description
  ssh_allow_cidrs                       = local.admin_cidr_blocks 

  # Licensing and Fleet
  fleet_community_string = local.community_string
  fleet_token            = local.fleet_token
  fleet_url              = local.fleet_api_url
  fleet_server_sslname   = local.fleet_server_ssl_name
}