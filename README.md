# Fantasy BR

Data pipeline and analytics platform for Cartola FC, Brazil's most popular fantasy football game based on the Brasileirão league.

## Overview

This project provides:

- **Daily data ingestion** from Cartola FC API
- **Historical data** from 2025 and 2026 seasons (via dbt seeds)
- **Analytics models** for player performance across different time windows
- **Infrastructure as Code** with Terraform for Google BigQuery

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Cartola API    │     │  Legacy CSVs    │     │  dbt Seeds      │
│  (daily load)   │     │  (2025/2026)    │     │  (historical)   │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                      raw_players (BigQuery)                      │
│                         (nested scout)                           │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                        stg_players                               │
│              (unified view: API + seeds)                         │
└─────────────────────────────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  int_players    │     │  KPI Models     │     │  Other Models   │
│  (intermediate) │     │  (last_1/3/5)   │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) for Python package management
- [Terraform](https://www.terraform.io/downloads) >= 1.0 for infrastructure
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) for GCP authentication

## Environments

| Environment | Dataset            | Terraform State Bucket  | Purpose      |
| ----------- | ------------------ | ----------------------- | ------------ |
| dev         | fdmdev_fantasy_br  | fantasy-br-tfstate-dev  | Development  |
| demo        | fdmdemo_fantasy_br | fantasy-br-tfstate-demo | Staging/Demo |
| prod        | fdmprod_fantasy_br | fantasy-br-tfstate-prod | Production   |

## Quick Start

```bash
# Install dependencies
uv sync

# Authenticate with GCP
gcloud auth application-default login

# Initialize infrastructure (dev)
cd infra && terraform init -backend-config="bucket=fantasy-br-tfstate-dev"
terraform apply -var-file=envs/dev.tfvars

# Run dbt
cd src/dbt
uv run dbt seed      # Load historical data
uv run dbt run       # Run all models
uv run dbt test      # Run tests
```

## CI/CD Workflows

| Workflow              | Trigger          | Description                                  |
| --------------------- | ---------------- | -------------------------------------------- |
| `data-refresh.yaml`   | Daily 8 AM UTC   | Loads fresh data from Cartola API + runs dbt |
| `implementation.yaml` | Push to main     | Deploys to dev → demo → prod                 |
| `development.yaml`    | Push to non-main | Deploys to dev only                          |

## Project Structure

```
fantasy-br/
├── src/
│   ├── app/              # Streamlit web application
│   ├── dbt/              # dbt project
│   │   ├── models/       # SQL models
│   │   │   ├── staging/  # stg_players (unified source)
│   │   │   ├── intermediate/  # int_players
│   │   │   ├── last_1/   # Last round stats
│   │   │   ├── last_3_home/  # Last 3 home matches
│   │   │   ├── last_3_away/  # Last 3 away matches
│   │   │   ├── last_5/   # Last 5 matches
│   │   │   ├── last_season/  # Previous season stats
│   │   │   └── this_season/  # Current season stats
│   │   └── seeds/        # Historical data (2025, 2026)
│   └── legacy/           # Legacy notebooks and reports
├── infra/                # Terraform (BigQuery infrastructure)
├── scripts/              # Utility scripts
├── tests/                # pytest tests
└── legacy/               # Historical CSV data by season
```

## dbt Models

### Staging

- **stg_players**: Unified view combining raw_players (API) + seed data (2025/2026)

### KPI Views

| Model             | Description                    |
| ----------------- | ------------------------------ |
| `kpi_last_1`      | Stats from last round          |
| `kpi_last_3_home` | Stats from last 3 home matches |
| `kpi_last_3_away` | Stats from last 3 away matches |
| `kpi_last_5`      | Stats from last 5 matches      |
| `kpi_last_season` | Previous season aggregate      |
| `kpi_this_season` | Current season aggregate       |

## Business Rules

- **Position ID 6 = Head Coach**: Excluded from player models (coaches have different scoring)
- **Scout fields**: Player actions (G=goals, A=assists, SG=clean sheet, etc.)
- **Round (rodada)**: Each game week in the Brasileirao season (38 rounds total)

## Development

### Install dependencies

```bash
uv sync
```

### Run tests

```bash
uv run pytest tests/
```

### Linting and formatting

```bash
uvx ruff check --fix
uvx ruff format
```

## Infrastructure

See [infra/README.md](infra/README.md) for detailed Terraform setup instructions.
