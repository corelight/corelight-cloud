locals {
  vpc_id                         = "<vpc where resources are deployed>"
  public_subnets                 = ["<public subnet 1>", "<public subnet 2>"]
  private_subnet                 = "<private subnet>"
  route53_zone_name              = "<route53 zone name>"
  subdomain                      = "<subdomain for fleet>"
  certificate_arn                = "<certificate arn for fleet>"
  aws_key_pair_name              = "<aws key pair name>"
  community_string               = "<community string for fleet>"
  fleet_username                 = "<fleet username>"
  fleet_password                 = "<fleet password>"
  fleet_api_password             = "<fleet API password>"
  fleet_certificate_file_path    = "<path to fleet certificate file>"
  fleet_sensor_license_file_path = "<path to fleet sensor license file>"
}

module "fleet" {
  source = "github.com/corelight/terraform-aws-fleet"

  vpc_id                         = local.vpc_id
  public_subnets                 = local.public_subnets
  private_subnet                 = local.private_subnet
  route53_zone_name              = local.route53_zone_name
  subdomain                      = local.subdomain
  certificate_arn                = local.certificate_arn
  aws_key_pair_name              = local.aws_key_pair_name
  community_string               = local.community_string
  fleet_username                 = local.fleet_username
  fleet_password                 = local.fleet_password
  fleet_api_password             = local.fleet_api_password
  fleet_certificate_file_path    = local.fleet_certificate_file_path
  fleet_sensor_license_file_path = local.fleet_sensor_license_file_path
}
