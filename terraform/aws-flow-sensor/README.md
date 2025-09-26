# Corelight AWS Flow Sensor Deployment (Private Preview)

This directory provides Terraform code for deploying Corelight's AWS Flow Sensor

## Overview

This example uses the [terraform-aws-single-sensor](https://github.com/corelight/terraform-aws-single-sensor) module 
to simplify the deployment of the Flow Sensor and includes example resources for authorizing it to the VPC Flow s3 bucket.

## Requirements & Considerations
* A Flow Sensor is paired (1:1) with an S3 bucket and should be deployed in the same region as the bucket
* Flow logs in the S3 bucket can originate from many regions, VPCs, and AWS accounts. Accounts that send flows to the S3 bucket will need a cross account role deployed and the Flow Sensor role will need 
  permission to assume into the cross account role
  * Deploy the role with [Terraform](https://github.com/corelight/terraform-aws-single-sensor/tree/main/modules/vpc_flow_assume_role)
* Multiple Flow Sensors can monitor a single bucket by configuring specific regions, VPCs, and AWS account filters to handle
  large scale VPC Flow log implementations
* The Flow Sensor should be deployed with a separate management and monitoring subnet 

## Supported Flow Log Configuration
Flow Logs will only be processed for VPCs with flow log configurations matching the following criteria:
  * Log Destination Target is `s3` 
  * AWS Default (v2) Log Format
  * `plain-text` File Format
  * `Per Hour Partition` and `Hive Compatible Partitions` are disabled
  * The S3 bucket destination must be structured with, at most, a single prefix level. The flow sensor will not 
    be able to process logs from S3 buckets with nested prefixes.
    * Supported: `arn:aws:s3:::bucket-name/prefix`
    * Not Supported: `arn:aws:s3:::bucket-name/prefix/another-prefix`

## Configuration
Once paired with Fleet, configure the AWS VPC Flow feature (Private Preview) under `Advanced` as follows:

| Configuration                          | Required | Default                    | Purpose                                                                                                                                                                              | Example                                 |
|----------------------------------------|----------|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------|
| `vpc_flow.enable`                      | YES      | N/A                        | Enables the service                                                                                                                                                                  | Toggle On                               |
| `vpc_flow.log_level`                   | NO       | `info`                     | The log level of the service                                                                                                                                                         | `debug`                                 |
| `vpc_flow.log_meta`                    | NO       | false                      | Adds the s3 object key, total flows, ENI, and AWS account ID to the resulting conn log                                                                                               | `true`                                  |
| `vpc_flow.aws.bucket_name`             | YES      | N/A                        | VPC flow log s3 bucket name                                                                                                                                                          | `vpc-flow-logs`                         |
| `vpc_flow.aws.bucket_region`           | YES      | N/A                        | VPC flow log bucket region                                                                                                                                                           | `us-east-1`                             |
| `vpc_flow.aws.start_date`              | YES      | N/A                        | Date to begin processing flows in AWS format (YYYY/MM/DD)                                                                                                                            | `2025/06/01`                            |
| `vpc_flow.aws.monitored_accounts`      | NO       | `nil`                      | Filters which account(s) the Flow Sensor will process logs. Attempts to process all accounts found in the bucket if not configured                                                   | `111111111111,222222222222`             |
| `vpc_flow.aws.monitored_vpcs`          | NO       | `nil`                      | Filters which VPC(s) the Flow Sensor will process logs. Attempts to process all VPCs with supported flow configurations found in each account if not configured                      | `vpc-12345,vpc-54321`                   |
| `vpc_flow.aws.monitored_regions`       | NO       | `Default AWS  Region List` | Filters which region(s) the Flow Sensor will process logs. Will enumerate VPCs in the `Default AWS Region List` if not configured                                                    | `us-east-1,us-east-2`                   |
| `vpc_flow.aws.cross_account_role_name` | NO       | `nil`                      | Name of the cross account role the Flow Sensor should assume into in each account. Will ignore any account that is not the account the Flow Sensor is deployed in if not configured. | `corelight-vpc-flow-cross-account-role` |

### Default AWS Region List
* `us-east-1`
* `us-east-2`
* `us-west-1`
* `us-west-2`
* `ap-south-1`
* `ap-northeast-1`
* `ap-northeast-2`
* `ap-northeast-3`
* `ap-southeast-1`
* `ap-southeast-2`
* `ca-central-1`
* `eu-central-1`
* `eu-west-1`
* `eu-west-2`
* `eu-west-3`
* `eu-north-1`
* `sa-east-1`


## Flow Sensor IAM

### EC2 Instance Profile Role
The EC2 instance will need permissions to read and list objects in the VPC Flow S3 bucket as well as enumerate VPCs and
VPC Flow Log configurations associated with VPCs in the account it is deployed. If the Flow Sensor does not need to
process any flows in the account it is deployed then the `ec2:DescribeVPCs` and `ec2:DescribeFlowLogs` permissions
can be removed.

**Note:** Replace `<vpc-flow-bucket-name>` and `<cross-region-role-name>` with your specific values.
```json
{
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::<vpc-flow-bucket-name>",
        "arn:aws:s3:::<vpc-flow-bucket-name>/*"
      ]
    },
    {
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeFlowLogs"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::*:role/<cross-region-role-name>"
    }
  ],
  "Version": "2012-10-17"
}
```

## Processing Flow Logs From Other Accounts
VPC Flow S3 buckets can contain flows from several accounts. The Flow Sensor requires a cross account role
in any account sending logs to the bucket it is paired with to process those logs. The Flow sensor will attempt to 
assume into accounts found in the bucket with the configured cross account role and will ignore any that are inaccessible.

### Example
For example, if the VPC Flow Sensor is deployed in account `111111111111` and is paired with the `vpc-flow-bucket`, the 
bucket may contain logs from other accounts. The following directory structure shows that logs are being sent from 
accounts `222222222222` and `333333333333`. The Flow Sensor will need a cross-account role in each of these accounts to
process the flow logs.

```
vpc-flow-bucket/
|-- AWSLogs/
|   |-- 111111111111/
|   |-- 222222222222/
|-- folder/
|   |-- AWSLogs/
|       |-- 333333333333/
```


## Cross Account IAM
The cross account policy and role can be created manually or through our 
[Terraform](https://github.com/corelight/terraform-aws-single-sensor/tree/main/modules/vpc_flow_assume_role) submodule. 

### Cross Account Trust Policy
Grant the IAM Role associated with your Flow Sensor EC2 instance profile access to enumerate VPCs and Flow log 
configurations in the other account(s)

**Note:** Replace `<ec2-instance-profile-iam-role>` with the name of the IAM role associated with your Flow Sensor EC2 
instance profile.
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                  "arn:aws:iam::111111111111:role/<ec2-instance-profile-iam-role>"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

### Cross Account Role Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVpcs",
                "ec2:DescribeFlowLogs"
            ],
            "Resource": "*"
        }
    ]
}
```