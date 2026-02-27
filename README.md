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
│   ├── app/                   # Streamlit web application
│   ├── dbt/                   # dbt project
│   │   ├── models/            # Data models
│   │   │   ├── staging/       # Staging models
│   │   │   ├── intermediate/  # Intermediate models
│   │   │   ├── kpis/          # KPI models
│   │   └── seeds/             # Historical data (2025, 2026)
├── infra/                     # Terraform (BigQuery infrastructure)
├── tests/                     # pytest tests
└── legacy/                    # Historical notebooks and reports
```

## dbt Models

### Staging

- **stg_players**: Unified view combining raw_players_etl (API) + seed data (2025/2026)

### KPI Views

| Model                   | Description                    |
| ----------------------- | ------------------------------ |
| `scounting_last_1`      | Stats from last round          |
| `scounting_last_5`      | Stats from last 5 matches      |
| `scounting_last_10`     | Stats from last 10 matches     |
| `scounting_last_5_home` | Stats from last 5 home matches |
| `scounting_last_5_away` | Stats from last 5 away matches |
| `scounting_last_season` | Previous season aggregate      |
| `scounting_this_season` | Current season aggregate       |

## Business Rules

- **Position ID 6 = Head Coach**: Excluded from player models (coaches have different scoring)
- **Scout fields**: Player actions (G=goals, A=assists, SG=clean sheet, etc.)
- **Round (rodada)**: Each game week in the Brasileirão season (38 rounds total)

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
