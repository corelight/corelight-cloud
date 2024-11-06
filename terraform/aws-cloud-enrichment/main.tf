locals {
  bucket_name              = "corelight-enrichment"
  image_name               = "12345.dkr.ecr.us-east-1.amazonaws.com/corelight/sensor-enrichment-aws"
  image_tag                = "0.1.1"
  secondary_rule_name      = "corelight-ec2-state-change"
  vpc_id                   = "<vpc where resources are deployed>"
  monitoring_subnet        = "<monitoring subnet id>"
  management_subnet        = "<management subnet id>"
  sensor_ssh_key_pair_name = "<name of the ssh key in AWS used to access the sensor EC2 instances>"
  sensor_ami_id            = "<sensor ami id from Corelight>"
  license_key_file         = "/path/to/license.txt"
  my_regions = [
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2"
  ]

  tags = {
    terraform : true,
    example : true,
    purpose : "Corelight"
  }
}

####################################################################################################
# Create the bucket where all enrichment data will be stored
####################################################################################################
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

resource "aws_s3_bucket" "enrichment_bucket" {
  provider = aws.primary

  bucket = local.bucket_name

  tags = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enrichment_bucket_encryption" {
  provider = aws.primary

  bucket = aws_s3_bucket.enrichment_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

####################################################################################################
# Deploy the lambda and supporting resources for the primary region
####################################################################################################
data "aws_ecr_repository" "enrichment_repo" {
  name = "corelight/sensor-enrichment-aws"
}

module "enrichment_eventbridge_role" {
  source = "github.com/corelight/terraform-aws-enrichment//modules/iam/eventbridge"

  primary_event_bus_arn = module.enrichment.primary_event_bus_arn

  tags = local.tags
}

module "enrichment_lambda_role" {
  source = "github.com/corelight/terraform-aws-enrichment//modules/iam/lambda"

  enrichment_bucket_arn           = aws_s3_bucket.enrichment_bucket.arn
  enrichment_ecr_repository_arn   = data.aws_ecr_repository.enrichment_repo.arn
  lambda_cloudwatch_log_group_arn = module.enrichment.cloudwatch_log_group_arn

  tags = local.tags
}

module "enrichment" {
  source = "github.com/corelight/terraform-aws-enrichment"

  providers = {
    aws = aws.primary
  }

  corelight_cloud_enrichment_image      = local.image_name
  corelight_cloud_enrichment_image_tag  = local.image_tag
  enrichment_bucket_name                = aws_s3_bucket.enrichment_bucket.bucket
  scheduled_sync_regions                = local.my_regions
  eventbridge_iam_cross_region_role_arn = module.enrichment_eventbridge_role.cross_region_role_arn
  lambda_iam_role_arn                   = module.enrichment_lambda_role.lambda_iam_role_arn

  tags = local.tags
}

####################################################################################################
# Deploy Corelight sensor and assign autoscaling group permission to read from the bucket
####################################################################################################

data "aws_subnet" "management" {
  id = local.management_subnet
}

module "asg_lambda_role" {
  source = "github.com/corelight/terraform-aws-sensor//modules/iam/lambda"

  lambda_cloudwatch_log_group_arn = module.sensor.cloudwatch_log_group_arn
  security_group_arn              = module.sensor.management_security_group_arn
  sensor_autoscaling_group_name   = module.sensor.autoscaling_group_name
  subnet_arn                      = data.aws_subnet.management.arn

  tags = local.tags
}

module "sensor" {
  source = "github.com/corelight/terraform-aws-sensor"

  auto_scaling_availability_zones = ["us-east-1a"]
  aws_key_pair_name               = local.sensor_ssh_key_pair_name
  corelight_sensor_ami_id         = local.sensor_ami_id
  license_key                     = file(local.license_key_file)
  management_subnet_id            = local.management_subnet
  monitoring_subnet_id            = local.monitoring_subnet
  community_string                = "<password for the sensor api>"
  vpc_id                          = local.vpc_id
  asg_lambda_iam_role_arn         = module.asg_lambda_role.role_arn

  # Setting these will automatically configure cloud enrichment
  enrichment_bucket_name          = aws_s3_bucket.enrichment_bucket.id
  enrichment_bucket_region        = aws_s3_bucket.enrichment_bucket.region
  enrichment_instance_profile_arn = aws_iam_instance_profile.corelight_sensor.arn

  tags = local.tags
}

module "sensor_iam" {
  source = "github.com/corelight/terraform-aws-enrichment//modules/iam/sensor"

  enrichment_bucket_arn = aws_s3_bucket.enrichment_bucket.arn

  tags = local.tags
}

resource "aws_iam_instance_profile" "corelight_sensor" {
  name = "corelight-sensor-profile"
  role = module.sensor_iam.sensor_role_name

  tags = local.tags
}

####################################################################################################
# Setup providers and deploy the "Fan In" event bus resources in each secondary region
####################################################################################################

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}


module "secondary_eventbridge_rule_us-east-2" {
  source = "github.com/corelight/terraform-aws-enrichment//modules/secondary_event_rule"

  providers = {
    aws = aws.us-east-2
  }

  cross_region_eventbridge_role_arn    = module.enrichment_eventbridge_role.cross_region_role_arn
  primary_event_bus_arn                = module.enrichment.primary_event_bus_arn
  secondary_ec2_state_change_rule_name = "${local.secondary_rule_name}-us-east-2"

  tags = local.tags
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
}

module "secondary_eventbridge_rule_us-west-1" {
  source = "github.com/corelight/terraform-aws-enrichment//modules/secondary_event_rule"

  providers = {
    aws = aws.us-west-1
  }

  cross_region_eventbridge_role_arn    = module.enrichment_eventbridge_role.cross_region_role_arn
  primary_event_bus_arn                = module.enrichment.primary_event_bus_arn
  secondary_ec2_state_change_rule_name = "${local.secondary_rule_name}-us-west-1"

  tags = local.tags
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

module "secondary_eventbridge_rule_us-west-2" {
  source = "github.com/corelight/terraform-aws-enrichment//modules/secondary_event_rule"

  providers = {
    aws = aws.us-west-2
  }

  cross_region_eventbridge_role_arn    = module.enrichment_eventbridge_role.cross_region_role_arn
  primary_event_bus_arn                = module.enrichment.primary_event_bus_arn
  secondary_ec2_state_change_rule_name = "${local.secondary_rule_name}-us-west-2"

  tags = local.tags
}