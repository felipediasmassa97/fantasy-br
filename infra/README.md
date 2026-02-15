# Infrastructure

Terraform configuration for Google BigQuery infrastructure.

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads) >= 1.0
2. [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) configured
3. A GCP project with BigQuery API enabled

### Install Terraform

**macOS (Homebrew):**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Verify installation:**

```bash
terraform --version
```

## Authentication

Authenticate with GCP:

```bash
gcloud auth application-default login
```

## Usage

### Initialize Terraform

```bash
cd infra
terraform init
```

### Deploy to an environment

Or use the ENVIRONMENT variable pattern:

```bash
export ENVIRONMENT=dev
terraform plan -var-file=envs/${ENVIRONMENT}.tfvars
terraform apply -var-file=envs/${ENVIRONMENT}.tfvars
```

### Environments

| Environment | Database Name | Dataset ID         |
| ----------- | ------------- | ------------------ |
| dev         | fdmdev        | fdmdev_fantasy_br  |
| demo        | fdmdemo       | fdmdemo_fantasy_br |
| prod        | fdmprod       | fdmprod_fantasy_br |

## BigQuery Free Tier Limits

- 10 GB storage per month
- 1 TB queries per month
- No charge for loading data

See [BigQuery pricing](https://cloud.google.com/bigquery/pricing) for details.
