# Agent Guidelines

Instructions for AI agents working on this project.

## Tech Stack

- **Language**: Python 3.13
- **Infrastructure**: Terraform for Google BigQuery (GCS backend per environment)
- **Data Transformation**: dbt-bigquery v1.11.5
- **Web Application**: Streamlit
- **Package Management**: uv
- **Testing**: pytest (no mocks)
- **Linting & Formatting**: ruff
- **CI/CD**: GitHub Actions with reusable workflows

## Project Structure

```
fantasy-br/
├── src/
│   ├── app/              # Streamlit application
│   ├── dbt/              # dbt project (models, seeds, macros)
│   └── legacy/           # Legacy Jupyter notebooks
├── infra/                # Terraform (BigQuery infrastructure)
│   └── envs/             # Environment-specific tfvars (dev, demo, prod)
├── tests/                # pytest tests
├── legacy/               # Historical CSV data by season (2025/, 2026/)
└── .github/workflows/    # CI/CD pipelines
```

## Environments

| Environment | Dataset            | State Bucket            | Purpose     |
| ----------- | ------------------ | ----------------------- | ----------- |
| dev         | fdmdev_fantasy_br  | fantasy-br-tfstate-dev  | Development |
| demo        | fdmdemo_fantasy_br | fantasy-br-tfstate-demo | Staging     |
| prod        | fdmprod_fantasy_br | fantasy-br-tfstate-prod | Production  |

## Business Domain: Cartola FC

Cartola FC is Brazil's most popular fantasy football game based on the Brasileirao league.

### Key Concepts

- **Temporada (Season)**: Calendar year (e.g., 2025, 2026)
- **Rodada (Round)**: Game week in the season (1-38 rounds per season)
- **Atleta (Player)**: Football player with stats per round
- **Scout**: Player actions that affect scoring

### Scout Fields (Scoring Actions)

| Code | Description          | Portuguese              |
| ---- | -------------------- | ----------------------- |
| G    | Goals scored         | Gols                    |
| A    | Assists              | Assistências            |
| SG   | Clean sheet          | Sem Gols (defesa)       |
| DE   | Saves (inside area)  | Defesas                 |
| DS   | Saves (outside area) | Defesas fora área       |
| GC   | Goals conceded       | Gols contra             |
| CV   | Red card             | Cartão vermelho         |
| CA   | Yellow card          | Cartão amarelo          |
| FC   | Fouls committed      | Faltas cometidas        |
| FS   | Fouls suffered       | Faltas sofridas         |
| FD   | Tackles won          | Finalizações defendidas |
| FF   | Shots off target     | Finalizações fora       |
| FT   | Shots on target      | Finalizações no gol     |
| DP   | Penalties saved      | Defesa de pênalti       |
| GS   | Penalty goals scored | Gol de pênalti          |
| PC   | Penalty missed       | Pênalti perdido         |
| I    | Impediments          | Impedimentos            |
| PP   | Passes intercepted   | Passes perdidos         |
| PS   | Penalty suffered     | Pênalti sofrido         |
| V    | Victories            | Vitórias                |

### Position IDs

| ID  | Position   | Portuguese                            |
| --- | ---------- | ------------------------------------- |
| 1   | Goalkeeper | Goleiro                               |
| 2   | Fullback   | Lateral                               |
| 3   | Defender   | Zagueiro                              |
| 4   | Midfielder | Meia                                  |
| 5   | Forward    | Atacante                              |
| 6   | Coach      | Técnico (excluded from player models) |

## Data Architecture

### Raw Layer

- **raw_players**: Loaded daily from Cartola API (nested `scout` STRUCT)

### Staging Layer

- **stg_players**: Unified view combining:
  - raw_players (API data)
  - players_2025 seed (historical)
  - players_2026 seed (historical)
  - Reconstructs nested `scout` STRUCT from flat seed columns

### KPI Models

- `kpi_last_1`: Last round performance
- `kpi_last_3_home`: Last 3 home matches
- `kpi_last_3_away`: Last 3 away matches
- `kpi_last_5`: Last 5 matches (any venue)
- `kpi_last_season`: Previous season aggregate
- `kpi_this_season`: Current season aggregate

## Development Workflow & Commands

### Code Style

- Do not commit changes unless explicitly asked
- Avoid fallbacks; throw errors instead
- Do not use emojis
- Use single-line docstrings
- Do not use generic try/except blocks

### Linting and Formatting

```bash
# Fix linting (run multiple times if needed)
uvx ruff check --fix

# Format code
uvx ruff format
```

### Terraform

```bash
cd infra

# Initialize for an environment
terraform init -backend-config="bucket=fantasy-br-tfstate-dev"

# Deploy
terraform apply -var-file=envs/dev.tfvars
```

### dbt

All commands run from `src/dbt/`:

```bash
cd src/dbt

# Verify connection
uv run dbt debug

# Load seeds (historical data)
uv run dbt seed

# Run all models
uv run dbt run

# Run specific model
uv run dbt run --select stg_players

# Run with dependencies
uv run dbt run --select +kpi_last_5

# Build all models (runs seeds, models, tests and snapshots)
uv run dbt build

# Test models
uv run dbt test

# Full refresh
uv run dbt run --full-refresh

# Target specific environment
uv run dbt run --target demo
```

After making dbt changes, always run `dbt build` to verify everything is working.

### Testing

```bash
# Single test
uv run --env-file .env pytest <PATH>::<TEST> --log-cli-level=INFO

# Parallel tests
uv run --env-file .env pytest <PATH> -n auto
```

Do not use mocks in tests.

### Creating Seeds from Legacy Data

```bash
uv run python scripts/create_seeds.py
```

This combines CSVs from `legacy/{year}/` into dbt seeds at `src/dbt/seeds/`.

## CI/CD Workflows

| File                  | Trigger          | Jobs                                  |
| --------------------- | ---------------- | ------------------------------------- |
| `data-refresh.yaml`   | Daily 8 AM UTC   | Load Cartola API → dbt run (all envs) |
| `implementation.yaml` | Push to main     | infra+dbt: dev → demo → prod          |
| `development.yaml`    | Push to branches | infra+dbt: dev only                   |

### Reusable Workflows

- `reusable-infra-deploy.yaml`: Creates GCS bucket + Terraform apply
- `reusable-dbt-run.yaml`: Seeds + dbt run

## Common Tasks

### Add new KPI model

1. Create SQL in appropriate folder under `src/dbt/models/`
2. Run `uv run dbt run --select new_model`
3. Test with `uv run dbt test --select new_model`

### Update historical data

1. Add/update CSVs in `legacy/{year}/`
2. Run `uv run python scripts/create_seeds.py`
3. Update `stg_players.sql` if column structure changed
4. Run `uv run dbt seed && uv run dbt run`

### Add new environment

1. Create `infra/envs/{env}.tfvars`
2. Update workflows to include new environment
3. Add IAM permissions for service account
