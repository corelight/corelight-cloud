module "aws_single_sensor" {
  source = "github.com/corelight/terraform-aws-single-sensor?ref=v1.0.0"

  instance_name             = "" // provide the flow sensor a name
  ami_id                    = "" // Corelight provided AMI ID
  aws_key_pair_name         = "" // provide an AWS SSH key pair name to associate with the instance
  fleet_community_string    = "" // provide your fleet instance's community string
  iam_instance_profile_name = aws_iam_instance_profile.sensor_profile.name

  // ENIs can be created by the module or provided. See the referenced module for more details
  // https://github.com/corelight/terraform-aws-single-sensor

  // -- New ENI Example --
  monitoring_interface_subnet_id   = "" // Typically a private subnet
  monitoring_security_group_vpc_id = "" // VPC ID of subnet

  management_interface_subnet_id   = ""   // Typically a public or SSH accessible subnet
  management_interface_public_ip   = true // (Optional) Set to true if in a public subnet w/ IGW
  management_security_group_vpc_id = ""   // VPC ID of subnet

  ssh_allow_cidrs = [""] // CIDR range(s) that should be allowed to SSH to the flow sensor

  // provide the fleet configuration from a "New Sensor"
  fleet_token          = ""
  fleet_url            = ""
  fleet_server_sslname = ""
}

resource "aws_iam_instance_profile" "sensor_profile" {
  // name the EC2 instance profile
  name = ""
  role = aws_iam_role.flow_role.name
}

data "aws_iam_policy_document" "flow_policy_data" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      // provide the flow sensor access to read from the flow log bucket
      "arn:aws:s3:::<vpc-flow-bucket-name>/*",
      "arn:aws:s3:::<vpc-flow-bucket-name>",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeFlowLogs"
    ]
    resources = ["*"]
  }
  // Add if flows originate from other accounts to grant the ability to assume into other roles
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::*:role/<cross-region-role-name>"
    ]
  }
}

data "aws_iam_policy_document" "ec2_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_policy" "flow_policy" {
  name   = "corelight-vpc-flow-sensor-policy"
  policy = data.aws_iam_policy_document.flow_policy_data.json
}

resource "aws_iam_role" "flow_role" {
  name               = "corelight-vpc-flow-sensor-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_policy.json
}

resource "aws_iam_role_policy_attachment" "flow_policy_role_attach" {
  policy_arn = aws_iam_policy.flow_policy.arn
  role       = aws_iam_role.flow_role.id
}
