# Fantasy BR

Data pipeline and analytics platform for Panela FC, built on top of Cartola FC — Brazil's most popular fantasy football game based on the Brasileirão league.

## Overview

This project provides analytics to maximize performance on Panela FC:

- **Daily data ingestion** from the Cartola FC API into BigQuery
- **Historical data** for 2025 and 2026 seasons (via dbt seeds)
- **dbt transformation pipeline** with staging, intermediate and mart layers
- **Streamlit analytics app** with four pages: Scouting, Start or Sit, Market Valuation, Squad and Team
- **Infrastructure as Code** with Terraform on GCP (BigQuery + Cloud Storage + Firestore)

## Architecture

```
┌──────────────────┐     ┌──────────────────────┐
│  Cartola FC API  │     │  Legacy CSVs         │
│  (daily ingest)  │     │  2025 / 2026 seeds   │
└────────┬─────────┘     └──────────┬───────────┘
         │                          │
         ▼                          ▼
┌────────────────────────────────────────────────┐
│           BigQuery raw tables                  │
│  raw_players_etl, raw_clubs, raw_matches, ...  │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│               staging (views)                  │
│  stg_players, stg_clubs, stg_matches, ...      │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│             intermediate (views)               │
│  general · scouting · start_or_sit ·           │
│  market_valuation                              │
└──────┬──────────────┬──────────────┬───────────┘
       │              │              │
       ▼              ▼              ▼
┌───────────┐  ┌────────────┐  ┌──────────────────┐
│ scouting  │  │start_or_sit│  │market_valuation  │
│ (tables)  │  │  (tables)  │  │   (tables)       │
└───────────┘  └────────────┘  └──────────────────┘
       │              │              │
       └──────────────┴──────────────┘
                      │
                      ▼
          ┌───────────────────────┐
          │   Streamlit App       │
          │  (3 analytics pages)  │
          └───────────────────────┘
```

## Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) for Python package management
- [Terraform](https://www.terraform.io/downloads) >= 1.0 for infrastructure
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) for GCP authentication
- A GCP project with the following APIs enabled: BigQuery, Cloud Storage, Firestore, Cloud Resource Manager

## Environments

| Environment | Purpose     | BigQuery Dataset   | Terraform State Bucket  |
| ----------- | ----------- | ------------------ | ----------------------- |
| dev         | Development | fdmdev_fantasy_br  | fantasy-br-tfstate-dev  |
| demo        | Staging     | fdmdemo_fantasy_br | fantasy-br-tfstate-demo |
| prod        | Production  | fdmprod_fantasy_br | fantasy-br-tfstate-prod |

## Quick Start

```bash
# Install all dependencies
uv sync --all-extras

# Authenticate with GCP
gcloud auth application-default login

# Initialize and deploy infrastructure (dev)
uv run terraform init -chdir=infra -backend-config="bucket=fantasy-br-tfstate-dev"
uv run terraform apply -chdir=infra -var-file=infra/envs/dev.tfvars

# Set up dbt
uv run dbt debug          # verify BigQuery connection
uv run dbt seed           # load historical data
uv run dbt build          # run all models + tests

# Start the Streamlit app
uv run app
```

## Script Aliases

All commands run from the repo root via `uv run`:

| Command             | Description                              |
| ------------------- | ---------------------------------------- |
| `uv run app`        | Start the Streamlit app (localhost:8501) |
| `uv run dbt <args>` | Run any dbt command from `src/dbt/`      |
| `uv run lint-sql`   | Lint all dbt SQL with SQLFluff           |
| `uv run format-sql` | Auto-fix all dbt SQL with SQLFluff       |
| `uv run lint-app`   | Lint all app Python with ruff            |
| `uv run format-app` | Auto-fix and format all app Python       |

## Project Structure

```
fantasy-br/
├── scripts/
│   └── __init__.py           # CLI entry points (run_app, run_dbt, lint_sql, ...)
├── src/
│   ├── app/                  # Streamlit application
│   │   ├── main.py           # Entry point (navigation)
│   │   ├── utils.py          # Shared loaders and helpers
│   │   └── pages/
│   │       ├── scouting.py
│   │       ├── start_or_sit.py
│   │       └── market_valuation.py
│   └── dbt/                  # dbt project (models, seeds, macros)
├── infra/                    # Terraform (BigQuery + Firestore infrastructure)
├── tests/                    # pytest tests
├── legacy/                   # Legacy Jupyter notebooks and CSVs
└── .github/                  # CI/CD pipelines
```

## dbt Models

### Scouting mart

| Model             | Description                      |
| ----------------- | -------------------------------- |
| `sct_last_1`      | Stats from the most recent round |
| `sct_last_5`      | Rolling last-5 rounds aggregate  |
| `sct_last_5_home` | Rolling last-5 home rounds       |
| `sct_last_5_away` | Rolling last-5 away rounds       |
| `sct_last_10`     | Rolling last-10 rounds aggregate |
| `sct_this_season` | Current season cumulative stats  |
| `sct_last_season` | Prior season cumulative stats    |

### Start or Sit mart

| Model               | Description                                              |
| ------------------- | -------------------------------------------------------- |
| `ss_main`           | Final MAP score per player                               |
| `ss_map_breakdown`  | Component multipliers (baseline, form, venue, mpap)      |
| `ss_mpap_debug`     | Matchup-adjusted points allowed per position diagnostics |
| `ss_splits`         | Home/away splits                                         |
| `ss_distribution`   | P20/P50/P80, CV, boom/bust rates                         |
| `ss_round_by_round` | Per-round history with opponent                          |
| `ss_edge_cases`     | Data quality flags                                       |

### Market Valuation mart

| Model               | Description                                      |
| ------------------- | ------------------------------------------------ |
| `mv_main`           | PAR (Points Above Replacement) and value summary |
| `mv_par_breakdown`  | PAR components by position                       |
| `mv_stabilized`     | Stabilized mean via shrinkage blending           |
| `mv_form_trend`     | Form trend (UP/FLAT/DOWN) and EWM averages       |
| `mv_regression`     | Regression-to-mean signals (SELL_HIGH/BUY_LOW)   |
| `mv_value_profile`  | Combined value profile per player                |
| `mv_round_by_round` | Per-round value history                          |

## Streamlit App

The app has three analytics pages, each loading from the corresponding mart tables:

| Page             | Description                                                           |
| ---------------- | --------------------------------------------------------------------- |
| Scouting         | Player performance rankings across 7 time windows                     |
| Start or Sit     | MAP (Multi-factor Adjusted Projection) for lineup decisions           |
| Market Valuation | PAR, stabilized mean, form trend and regression signals for transfers |
| Squad and Team   | Persist squad and team players for filtering in analytics pages       |

Configure credentials in `src/app/.streamlit/secrets.toml` with a `gcp_service_account` key.

## Development

### Install dependencies

```bash
uv sync --all-extras           # all groups (app + dbt + dev)
uv sync --group app            # app only
uv sync --group dbt            # dbt only
```

### Linting and formatting

```bash
uv run lint-app                # ruff check src/app/
uv run format-app              # ruff fix + format src/app/
uv run lint-sql                # sqlfluff lint src/dbt/
uv run format-sql              # sqlfluff fix src/dbt/
```

### dbt

```bash
uv run dbt debug               # verify connection
uv run dbt seed                # load seeds
uv run dbt build               # seeds + models + tests
uv run dbt run --select +ss_main   # run model with upstream deps
uv run dbt run --full-refresh  # rebuild all tables
uv run dbt run --target demo   # target a specific environment
```

After making dbt changes, always run `uv run dbt build` to verify.

### Testing

```bash
uv run --env-file .env pytest tests/           # all tests
uv run --env-file .env pytest tests/ -n auto   # parallel
```

Do not use mocks.

## CI/CD Workflows

| File                         | Trigger            | Jobs                                    |
| ---------------------------- | ------------------ | --------------------------------------- |
| `data-refresh.yaml`          | Daily 3 AM UTC     | Load Cartola API → dbt build (all envs) |
| `implementation.yaml`        | Push to `main`     | infra + dbt: dev → demo → prod          |
| `development.yaml`           | Push to non-`main` | infra + dbt: dev only                   |
| `reusable-infra-deploy.yaml` | Called by above    | GCS bucket + Terraform apply            |
| `reusable-dbt-build.yaml`    | Called by above    | `dbt seed && dbt build`                 |

## Infrastructure

Managed with Terraform on Google Cloud Platform. Resources per environment:

- **Cloud Storage bucket**: Terraform remote state backend
- **BigQuery dataset**: holds all dbt staging, intermediate and mart tables
- **Firestore database**: persists user squads and teams (`user_squads` and `user_teams` collections)
- **IAM bindings**: grants the service account `roles/datastore.user`, `roles/bigquery.dataViewer`, and `roles/bigquery.jobUser`

### Install Terraform

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify
terraform --version
```

### Authenticate with GCP

```bash
gcloud auth application-default login
```

### Deploy

```bash
# Initialize backend (once per environment)
uv run terraform init -chdir=infra -backend-config="bucket=fantasy-br-tfstate-dev"

# Preview and apply
uv run terraform plan -chdir=infra -var-file=infra/envs/dev.tfvars
uv run terraform apply -chdir=infra -var-file=infra/envs/dev.tfvars
```

### Free tier limits (per month)

- **BigQuery**: 10 GB storage, 1 TB queries, free data loads ([pricing](https://cloud.google.com/bigquery/pricing)).
- **Firestore**: 1 GiB storage, 50K reads/day, 20K writes/day ([pricing](https://cloud.google.com/firestore/pricing)).
