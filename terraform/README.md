# Terraform

This directory contains **Terraform** modules used to deploy Corelight solutions
across multiple cloud providers.

#### Subdirectories

- **`aws-autoscaling-sensor/`**: Contains Terraform files for deploying an
    autoscaling sensor within AWS, including `main.tf` and `versions.tf` files for configuration.
- **`aws-cloud-enrichment/`**: A Terraform module for setting up cloud enrichment
    services on AWS.
- **`azure-cloud-enrichment/`**: Module to configure cloud enrichment capabilities
    on Azure.
- **`azure-scaleset-sensor/`**: Azure Terraform configuration to deploy Corelight
    sensors on a Virtual Machine Scale Set.
- **`gcp-mig-sensor/`**: A Terraform module for deploying a sensor with GCP’s
    Managed Instance Groups (MIG).
- **`gcp-cloud-enrichment/`**: GCP-specific Terraform module for configuring cloud
    enrichment services.
- **`integrations/`**: Subdirectories for integrating Corelight products with
    partner solutions.

## How to Use

Navigate into the appropriate directory and follow the instructions provided in
the `README.md` for each module.
