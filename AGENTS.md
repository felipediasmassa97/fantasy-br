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

## General Instructions

### Style

- Do not commit changes unless explicitly asked
- Avoid fallbacks; throw errors instead
- Do not use emojis
- Use single-line docstrings
- Do not use generic try/except blocks

### Processes

- Always update documentation (`AGENTS.md`, `README.md`, `pyproject.toml`, `src/dbt/sources.yml`, `src/dbt/dbt_project.yml`, `src/dbt/profiles.yml`, ...) after implementing features and making changes
- After making dbt changes, always run `dbt build` with modified models selected to verify everything is working
- Always run linting and formatting for Streamlit and dbt using their appropriate frameworks.

## Project Structure

```
fantasy-br/
├── src/
│   ├── app/              # Streamlit application
│   └── dbt/              # dbt project (models, seeds, macros)
├── infra/                # Terraform (BigQuery infrastructure)
├── tests/                # pytest tests
├── legacy/               # Legacy Jupyter notebooks and spreadsheets
└── .github/              # CI/CD pipelines
```

## Environments

| Environment | Purpose     | Streamlit                             | Dataset (Big Query) | State Bucket (Big Query) |
| ----------- | ----------- | ------------------------------------- | ------------------- | ------------------------ |
| dev         | Development | Local development only, no deployment | fdmdev_fantasy_br   | fantasy-br-tfstate-dev   |
| demo        | Staging     | No deployment                         | fdmdemo_fantasy_br  | fantasy-br-tfstate-demo  |
| prod        | Production  | Streamlit Cloud                       | fdmprod_fantasy_br  | fantasy-br-tfstate-prod  |

## Business Domain: Cartola FC and Panela FC

Cartola FC is Brazil's most popular fantasy football game based on the Brasileirão league.

Panela FC is an implementation on top of Cartola FC. It uses the same rules for lineups and player individual scoring, but provides modified rules for player selection and scoring.

Your objective is to develop analytics aiming to maximize performance on Panela FC. Even though, Cartola FC concepts and dynamics will be provided for context (since it is the building block for Panela FC).

### Key Concepts

- **Temporada (Season)**: Calendar year (e.g., 2025, 2026)
- **Rodada (Round)**: Game week in the season (1-38 rounds per season)
- **Atleta (Player)**: Football player with stats per round
- **Scout**: Player actions that affect scoring
- **Participant**: Human participants of a Cartola FC or Panela FC league, acting as general managers

### Scout Fields (Scoring Actions)

| Code | Description (EN)                 | Description (PT)       | Points |
| ---- | -------------------------------- | ---------------------- | ------ |
| G    | Goal scored                      | Gols                   | + 8.0  |
| A    | Assist                           | Assistências           | + 5.0  |
| FT   | Shot on post                     | Finalização na trave   | + 3.0  |
| FD   | Shot defended                    | Finalização defendidas | + 1.2  |
| FF   | Shot off target                  | Finalização para fora  | + 0.8  |
| PS   | Penalty suffered                 | Pênalti sofrido        | + 1.0  |
| FS   | Foul suffered                    | Falta sofridas         | + 0.5  |
| I    | Offside                          | Impedimento            | - 0.1  |
| PP   | Penalty missed                   | Pênalti perdido        | - 4.0  |
| DS   | Tackle succeeded                 | Desarme                | + 1.5  |
| FC   | Foul committed                   | Faltas cometida        | - 0.3  |
| PC   | Penalty committed                | Pênalti cometido       | - 1.0  |
| CA   | Yellow card                      | Cartão amarelo         | - 1.0  |
| CV   | Red card                         | Cartão vermelho        | - 3.0  |
| GC   | Own goal                         | Gol contra             | - 3.0  |
| SG   | Clean sheet (only GK, CB and FB) | Saldo de gols          | + 5.0  |
| DE   | Save (only GK)                   | Defesa                 | + 1.3  |
| DP   | Penalty saved (only GK)          | Defesa de pênalti      | + 7.0  |
| GS   | Goal against (only GK)           | Gol sofrido            | - 1.0  |

### Position IDs

| ID  | Position   | Portuguese                            |
| --- | ---------- | ------------------------------------- |
| 1   | Goalkeeper | Goleiro                               |
| 2   | Fullback   | Lateral                               |
| 3   | Defender   | Zagueiro                              |
| 4   | Midfielder | Meia                                  |
| 5   | Forward    | Atacante                              |
| 6   | Coach      | Técnico (excluded from player models) |

### Dynamics for Cartola FC

In a typical Cartola FC league, a lineup consisting of 11 starter players and 5 substitutes (1 per position) is selected by a participant in each round.

The constraint for a participant when defining players for their lineup is the total budget (starting at 100 Cartola FC coins - _cartoletas_). Each player costs a given number of _cartoletas_, which may increase or decrease throughout the league based on their performance.

A participant can completely change their lineup from one round to another (i.e. there is no "squad"), provided they stay within the _cartoletas_ budget.

The objective of the participants is to maximize the number of points based on their lineup performance.

Backup players add their points to participant score only if any starter from their position does not play in the round.

The participant score in a given round is given by the sum of points of all their players in the lineup. The participant with the most accumulated points after 38 rounds is the league winner.

### Dynamics for Panela FC

Base rules for Panela FC are the same as for Cartola FC, with the following changes:

- There are 10 total participants.

- The total pool of players a participant can select from is a squad, rather than the full pool of players. The squads are defined by a draft that takes place in the league start. Each participant has 23 players in their squad.

- Panela FC uses an arbitrary currency. Each participant starts the league with 1,000 coins.

- Participants can change their squad's players via free agents recruitment (costing no coins, but needing to release one player), trades with other players (1-1 players and coins possibly) or auction (highest bidder wins, bids are hidden from other participants).

- League format is round-robin. Each participant faces another one in each round. In total, there are 18 rounds (i.e. each participants faces the others twice).

## Architecture and Components

### Infra

Infra is managed within Google Cloud Platform (GCP) using Terraform for IaC.

The provisioned resources are:

- Big Query: data warehousing, integration with dbt and GitHub Actions.

- Cloud Storage: bucket to store Terraform state.

```bash
# Initialize for an environment
terraform init -chdir=infra -backend-config="bucket=fantasy-br-tfstate-dev"

# Deploy
terraform apply -chdir=infra -var-file=envs/dev.tfvars
```

### Data Project

Data is loaded from Cartola API to Big Query by a GitHub Actions' scheduled workflow (`data-refresh.yaml`).

Data is transformed and served to the Streamlit UI by `dbt`.

```
fantasy-br/
└── src/
    └── dbt/
        ├── macros/                            # reusable functions
        ├── models/
        │   ├── staging/                       # staging models
        │   ├── intermediate/                  # intermediate models
        │   ├── scouting/                      # mart models for Scouting
        │   ├── start_or_sit/                  # mart models for Start or Sit
        │   ├── market_valuation/              # mart models for Market Valuation
        │   └── sources.yml                    # sources definitions (data loaded by data-refresh workflow)
        ├── seeds/
        │   ├── raw_players_legacy_2025.csv    # legacy players' data for season 2025, rounds 1-38
        │   ├── raw_players_legacy_2026.csv    # legacy players' data for season 2026, rounds 1-2
        │   └── scout_points.csv               # scout points mapping (e.g.: goal = +8.0 points)
        ├── dbt_project.yml                    # dbt configuration (e.g.: materialization)
        └── profiles.yml                       # local, dev, demo and prod profiles definitions
```

### User Interface

Streamlit is used as web application development framework.

Each page in the multi-page application (MPA) renders data for a specific thematic analysis (Scouting, Start or Sit, Market Valuation).

```
fantasy-br/
└── src/
    └── app/
        ├── .streamlit/                    # Streamlit configuration (e.g.: theme, secrets)
        ├── pages/
        │   ├── scouting.py                # Scouting page
        │   ├── start_or_sit.py            # Start or Sit page
        │   ├── market_valuation.py        # Market Valuation page
        ├── main.py                        # Streamlit entry point
        └── utils.py                       # utility functions
```

### Raw Layer

- **raw_players_etl**: Loaded daily from Cartola API (nested `scout` STRUCT)

### Staging Layer

- **stg_players**: Unified view combining:
  - raw_players_etl (API data)
  - raw_players_legacy_2025 seed (historical)
  - raw_players_legacy_2026 seed (historical)
  - Reconstructs nested `scout` STRUCT from flat seed columns

### Scouting Models

- `sct_last_1`: Last round performance
- `sct_last_5`: Last 5 matches (any venue)
- `sct_last_10`: Last 10 matches
- `sct_last_5_home`: Last 5 home matches
- `sct_last_5_away`: Last 5 away matches
- `sct_last_season`: Previous season aggregate
- `sct_this_season`: Current season aggregate

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
uv run dbt run --select +sct_last_5

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
- `reusable-dbt-build.yaml`: Seeds + dbt build

## Common Tasks

# fixit add

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
