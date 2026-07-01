# ⚠️ DEPRECATED — This repository has moved

> **This repository is no longer maintained and has been archived (read-only).**

The Terraform examples in this repository now live in the
**[Corelight Terraform monorepo](https://github.com/corelight/terraform)** under
[`examples/`](https://github.com/corelight/terraform/tree/main/examples).

See the [monorepo README](https://github.com/corelight/terraform#readme) for the full module and example list.

> **Note:** The CloudFormation templates (`cloudformation/`) and partner
> integrations (`terraform/integrations/`) were not migrated to the monorepo and
> are no longer maintained.

---

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
