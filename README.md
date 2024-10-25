# Corelight Deployment Guide

This repository provides sample configurations for deploying Corelight products
across AWS, Azure, and Google Cloud Platform (GCP). The examples offer both
**Terraform-based** and **cloud-native IaC solutions**, allowing users to
choose based on their preferences and platform requirements.

## Directory Structure

### `terraform/`

Contains **Terraform** modules for deploying Corelight products with consistent
configurations across multiple clouds.

- **`aws/`**: Terraform modules for AWS deployments.
- **`azure/`**: Terraform modules for Azure deployments.
- **`gcp/`**: Terraform modules for GCP deployments.

### `cloud-native-iac/`

Includes cloud provider-native infrastructure-as-code (IaC) templates for deeper
integration with specific cloud services.

- **`aws/`**: CloudFormation templates for AWS deployments.

## License

The project is licensed under the [MIT][] license.

[MIT]: LICENSE
