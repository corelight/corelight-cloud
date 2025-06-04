# Corelight AWS Flow Sensor Deployment (Private Preview)

This directory provides Terraform code for deploying Corelight's AWS Flow Sensor

## Overview

This example uses the [terraform-aws-single-sensor](https://github.com/corelight/terraform-aws-single-sensor) module 
to simplify the deployment of the Flow sensor and includes example resources for authorizing it to the VPC Flow s3 bucket.

## Requirements & Considerations
* A Flow Sensor must be deployed in each AWS account
* The sensor should be deployed similarly to a traditional sensor with a separate management and monitoring subnet
* VPC Flow Logs will only be processed for VPCs with flow log configurations matching the following criteria:
  * Log Destination Target is `s3` 
  * AWS Default (v2) Log Format
  * `plain-text` File Format
  * `Per Hour Partition` and `Hive Compatible Partitions` are disabled

## Configuration 
Once connected to Fleet, configure the AWS VPC Flow feature (Private Preview) under `Advanced` is follows:
* Enable the feature by switching on `cloud_vpc_flow.enable`
* All configurations below are begin with `cloud_vpc_flow.`

| Configuration       | Required | Type   | Default Region                                                                                                                                                                                                                                                                               | Purpose                                                                | Example                 |
|---------------------|----------|--------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|-------------------------|
| `start_date`        | YES      | string | N/A                                                                                                                                                                                                                                                                                          | The AWS date used to begin process logs                                | `2025/06/01`            |
| `log_level`         | NO       | string | `info`                                                                                                                                                                                                                                                                                       | The log level of the service                                           | `debug` to troubleshoot |
| `monitored_vpcs`    | NO       | string | `null`                                                                                                                                                                                                                                                                                       |                                                                        | `vpc-12345,vpc-54321`   |
| `monitored_regions` | NO       | string | `us-east-1`<br/>`us-east-2`<br/>`us-west-1`<br/>`us-west-2`<br/>`ap-south-1`<br/>`ap-northeast-1`<br/>`ap-northeast-2`<br/>`ap-northeast-3`<br/>`ap-southeast-1`<br/>`ap-southeast-2`<br/>`ca-central-1`<br/>`eu-central-1`<br/>`eu-west-2`<br/>`eu-west-3`<br/>`eu-north-1`<br/>`sa-east-1` | Regions to enumerate for VPCs<br/> with compatible flow configurations | `us-east-1,us-east2`    |
| `s3_bucket_prefix`  | NO       | string | `AWSLogs`                                                                                                                                                                                                                                                                                    | VPC flow log s3 object prefix                                          | `AWSLogs`               |

## Limitations
* While a Flow Sensor can read from a s3 bucket that includes VPC Flow logs for multiple accounts, it will only process
    logs for the account in which it is deployed.

## IAM Policy JSON
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
        "arn:aws:s3:::<vpc-flow-bucket-name>/*",
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