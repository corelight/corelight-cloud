locals {
  vpc_id                   = "<vpc where resources are deployed>"
  management_subnet_ids    = ["management subnet 1", "management subnet 2"]
  monitoring_subnet_ids    = ["monitoring subnet 1", "monitoring subnet 2"]
  sensor_ssh_key_pair_name = "<name of the ssh key in AWS used to access the sensor EC2 instances>"
  sensor_ami_id            = "<sensor ami id from Corelight>"
  license                  = "<your corelight sensor license key>"
  tags = {
    terraform : true,
    purpose : "Corelight"
  }
  fleet_token          = "b1cd099ff22ed8a41abc63929d1db126"
  fleet_url            = "https://fleet.example.com:1443/fleet/v1/internal/softsensor/websocket"
  fleet_server_sslname = "SSL hostname for the fleet server"

}

data "aws_subnet" "management" {
  for_each = toset(local.management_subnet_ids)
  id       = each.value
}

module "asg_lambda_role" {
  source = "github.com/corelight/terraform-aws-sensor//modules/iam/lambda"

  lambda_cloudwatch_log_group_arn = module.sensor.cloudwatch_log_group_arn
  security_group_arn              = module.sensor.management_security_group_arn
  sensor_autoscaling_group_arn    = module.sensor.autoscaling_group_arn
  subnet_arns                     = [for subnet in data.aws_subnet.management : subnet.arn]

  tags = local.tags
}

module "sensor" {
  source = "github.com/corelight/terraform-aws-sensor"

  aws_key_pair_name       = local.sensor_ssh_key_pair_name
  corelight_sensor_ami_id = local.sensor_ami_id
  license_key             = local.license
  management_subnet_ids   = local.management_subnet_ids
  monitoring_subnet_ids   = local.monitoring_subnet_ids
  community_string        = "<password for the sensor api>"
  vpc_id                  = local.vpc_id
  asg_lambda_iam_role_arn = module.asg_lambda_role.role_arn
  fleet_token             = local.fleet_token
  fleet_url               = local.fleet_url
  fleet_server_sslname    = local.fleet_server_sslname

  tags = local.tags
}

module "bastion" {
  source = "github.com/corelight/terraform-aws-sensor//modules/bastion"

  bastion_key_pair_name        = "<AWS ssh key pair name for the bastion host>"
  subnet_id                    = data.aws_subnet.management.id
  management_security_group_id = module.sensor.management_security_group_id
  vpc_id                       = local.vpc_id
  public_ssh_allow_cidr_blocks = ["0.0.0.0/0"]

  tags = local.tags
}
