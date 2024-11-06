# Corelight Deployment Guide

This repository provides sample configurations for deploying Corelight products
across AWS, Azure, and Google Cloud Platform (GCP). The examples offer both
**Terraform-based** and **native IaC solutions**, allowing users to choose
the approach that best fits their platform requirements and preferences.

## Directory Structure Overview

### `cloudformation/`

This directory includes **AWS CloudFormation templates** for deploying Corelight
solutions within AWS environments using native AWS IaC. Each template provides
configurations tailored for Corelight.

### `terraform/`

The `terraform/` directory contains **Terraform modules** structured by cloud
provider. Each subdirectory under `terraform/` is organized by provider and
service, with individual `README.md` files for specific guidance on deploying
Corelight products within that cloud.

#### Integrations

Within `terraform/integrations/`, you’ll find subdirectories for integrating
Corelight products with partner solutions.

## License

The project is licensed under the [MIT][] license.

[MIT]: LICENSE
