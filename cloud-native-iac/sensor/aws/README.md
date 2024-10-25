# Corelight Sensor Deployment - AWS

This directory provides Cloud Formation code for deploying Corelight's Sensor
on **AWS**.

## Usage

Execute the following commands making sure to provide the appropriate
parameters for your environment.

Create a new stack:

```bash
aws cloudformation create-stack --region <AWS_REGION> \
  --stack-name corelight-sensor \
  --parameters \
    ParameterKey=DeploymentName,ParameterValue=<SENSOR_DEPLOYMENT_NAME> \
    ParameterKey=AutoScalingAvailabilityZones,ParameterValue=<SENSOR_AUTO_SCALING_AVAILABILITY_ZONES> \
    ParameterKey=ImageId,ParameterValue=<SENSOR_IMAGE_ID> \
    ParameterKey=VpcId,ParameterValue=<SENSOR_VPC_ID> \
    ParameterKey=MonitoringSubnetId,ParameterValue=<SENSOR_MONITORING_SUBNET_ID> \
    ParameterKey=MonitoringSubnetCIDR,ParameterValue=<SENSOR_MONITORING_SUBNET_CIDR> \
    ParameterKey=ManagementSubnetId,ParameterValue=<SENSOR_MANAGEMENT_SUBNET_ID> \
    ParameterKey=ManagementSubnetCIDR,ParameterValue=<SENSOR_MANAGEMENT_SUBNET_CIDR> \
    ParameterKey=KeyPairName,ParameterValue=<SENSOR_KEY_PAIR_NAME> \
  --template-body file://cfn.yaml
```

Update existing stack:

```bash
aws cloudformation update-stack --region <AWS_REGION> \
  --stack-name corelight-sensor \
  --parameters \
    ParameterKey=DeploymentName,ParameterValue=<SENSOR_DEPLOYMENT_NAME> \
    ParameterKey=AutoScalingAvailabilityZones,ParameterValue=<SENSOR_AUTO_SCALING_AVAILABILITY_ZONES> \
    ParameterKey=ImageId,ParameterValue=<SENSOR_IMAGE_ID> \
    ParameterKey=VpcId,ParameterValue=<SENSOR_VPC_ID> \
    ParameterKey=MonitoringSubnetId,ParameterValue=<SENSOR_MONITORING_SUBNET_ID> \
    ParameterKey=MonitoringSubnetCIDR,ParameterValue=<SENSOR_MONITORING_SUBNET_CIDR> \
    ParameterKey=ManagementSubnetId,ParameterValue=<SENSOR_MANAGEMENT_SUBNET_ID> \
    ParameterKey=ManagementSubnetCIDR,ParameterValue=<SENSOR_MANAGEMENT_SUBNET_CIDR> \
    ParameterKey=KeyPairName,ParameterValue=<SENSOR_KEY_PAIR_NAME> \
  --template-body file://cfn.yaml
```

[awscli]: https://aws.amazon.com/cli/
