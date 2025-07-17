# Corelight Fleet and Sensor - AWS

This directory provides Terraform code for deploying Corelight's Fleet application
with a connected sensor on **AWS**.

## Overview

This deployment first spins up a Corelight Fleet instance using the [terraform-aws-fleet][] module. Once Fleet is running, the [terraform-aws-single-sensor][] module automatically registers a sensor to that Fleet instance. 

Please note: It will take a few minutes for the sensor instance to be fully provisioned and registered with Fleet after deployment.

[terraform-aws-fleet]: https://github.com/corelight/terraform-aws-fleet/
[terraform-aws-single-sensor]: https://github.com/corelight/terraform-aws-single-sensor/