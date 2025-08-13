# Corelight AWS Flow Sensor Deployment (Private Preview)

This directory provides Terraform code for deploying Corelight's AWS Flow Sensor

## Overview

This example uses the [terraform-aws-single-sensor](https://github.com/corelight/terraform-aws-single-sensor) module 
to simplify the deployment of the Flow Sensor and includes example resources for authorizing it to the VPC Flow s3 bucket.

## Requirements & Considerations
* A Flow Sensor has a 1:1 association with an S3 bucket
* Many Accounts can feed flows to the single S3 bucket
* Any account sending flows to the S3 bucket will need a cross account role deployed 
* The sensor should be deployed similarly to a traditional sensor with a separate management and monitoring subnet
* VPC Flow Logs will only be processed for VPCs with flow log configurations matching the following criteria:
  * Log Destination Target is `s3` 
  * AWS Default (v2) Log Format
  * `plain-text` File Format
  * `Per Hour Partition` and `Hive Compatible Partitions` are disabled
* Only flow log configuration S3 destinations with one level of "folder" (prefix) are supported
  * supported: `arn:aws:s3:::bucket`
  * supported: `arn:aws:s3:::bucket/production`
  * not supported: `arn:aws:s3:::bucket/not/this`

## Configuration 
Once connected to Fleet, configure the AWS VPC Flow feature (Private Preview) under `Advanced` as follows
* Enable the feature by switching on `cloud_vpc_flow.enable`
* All configurations below begin with `cloud_vpc_flow.`

| Configuration             | Required | Type   | Default Region            | Purpose                                                                           | Example                                 |
|---------------------------|----------|--------|---------------------------|-----------------------------------------------------------------------------------|-----------------------------------------|
| `start_date`              | YES      | string | N/A                       | Date to begin processing flows in AWS format                                      | `2025/06/01`                            |
| `bucket_name`             | YES      | string | N/A                       | VPC flow log s3 bucket name                                                       | `vpc-flow-logs`                         |
| `bucket_region`           | YES      | string | N/A                       | VPC flow log bucket region                                                        | `us-east-1`                             |
| `log_level`               | NO       | string | `info`                    | The log level of the service                                                      | `debug`                                 |
| `monitored_accounts`      | NO       | string | `nil`                     | Filters which account(s) the Flow Sensor will process logs                        | `111111111111,222222222222`             |
| `monitored_vpcs`          | NO       | string | `nil`                     | Filters which VPC(s) the Flow Sensor will process logs                            | `vpc-12345,vpc-54321`                   |
| `monitored_regions`       | NO       | string | Default Region List Below | Filters which region(s) the Flow Sensor will process logs                         | `us-east-1,us-east-2`                   |
| `cross_account_role_name` | NO       | string | `nil`                     | Name of the cross account role the Flow Sensor should assume into in each account | `corelight-vpc-flow-cross-account-role` |

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

### Ec2 Instance Profile Role 
The EC2 instance will need permissions to read and list objects in the VPC Flow S3 bucket as well as enumerate VPCs and
VPC Flow Log configurations associated with VPCs in the account it is deployed. If the Flow Sensor does not need to 
process any flows in the account it is deployed then the `ec2:DescribeVPCs` and `ec2:DescribeFlowLogs` permissions 
can be removed.
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
    }
  ],
  "Version": "2012-10-17"
}
```

## Processing Flow Logs From Other Accounts
VPC Flow S3 buckets can contain flows from several other accounts. The Flow Sensor requires a cross account role
in any account sending logs to the bucket it is paired with to process them. Accounts found in the bucket where a cross 
account role is not provisioned will be ignored.

### Example
If the VPC Flow Sensor is deployed in `111111111111` paired with `vpc-flow-bucket` then it would need a cross account role
to enumerate VPC Flow configuration information in `222222222222` and `333333333333`
```
vpc-flow-bucket/
    -> AWSLogs/111111111111/
    -> AWSLogs/222222222222/
    -> folder/AWSLogs/333333333333/
```

### Cross Account Trust Policy
Grant the IAM Role associated with your Flow Sensor EC2 instance profile access to enumerate VPCs and Flow log 
configurations in the other account(s)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                  "arn:aws:iam::111111111111:role/corelight-vpc-flow-role"
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