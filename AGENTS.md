# Agent Guidelines

Instructions for AI agents working on this project.

## Tech Stack

- **Language**: Python 3.13
- **Infrastructure**: Terraform for Google BigQuery, Cloud Storage and Firestore (GCS backend per environment)
- **Data Transformation**: dbt-bigquery
- **Web Application**: Streamlit
- **Package Management**: uv (optional dependency groups: `app`, `dbt`, `tests`)
- **Testing**: pytest + pytest-xdist (no mocks)
- **Python Linting & Formatting**: ruff
- **SQL Linting & Formatting**: SQLFluff (dialect: BigQuery, templater: jinja)
- **CI/CD**: GitHub Actions with reusable workflows

## General Instructions

### Style

- Do not commit changes unless explicitly asked
- Avoid fallbacks; throw errors instead
- Do not use emojis
- Use single-line docstrings
- Do not use generic try/except blocks

### Processes

- Always update documentation (`AGENTS.md`, `README.md`, `pyproject.toml`, `src/dbt/models/sources.yml`, `src/dbt/dbt_project.yml`, `src/dbt/profiles.yml`) after implementing features and making changes
- After making dbt changes, always run `uv run dbt build` with modified models selected to verify everything is working
- After Python changes, run `uv run lint-app` and `uv run format-app`
- After SQL changes, run `uv run lint-sql` and `uv run format-sql`
- Do not use generic try/except blocks

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
│   │       ├── market_valuation.py
│   │       ├── squad_and_team.py
│   │       ├── trade_simulator.py
│   │       └── matchup_preview.py
│   └── dbt/                  # dbt project (models, seeds, macros)
├── infra/                    # Terraform infrastructure
│   ├── modules/              # Reusable modules (bigquery, firestore, iam)
│   └── envs/                 # Per-environment stacks (dev, demo, prod)
├── tests/                    # pytest tests
├── legacy/                   # Legacy Jupyter notebooks and CSVs
└── .github/                  # CI/CD pipelines
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
- **Rodada (Round)**: Match week in the season (1-38 rounds per season)
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

### Infrastructure

Managed with Terraform on GCP, using a modular structure with per-environment stacks:

- **BigQuery**: data warehousing, dbt and GitHub Actions integration
- **Cloud Storage**: Terraform state buckets (one per environment)
- **Firestore**: `user_squads`, `user_teams`, `user_opponent_squads` and `user_opponent_teams` collections for squad and team persistence

```
infra/
├── .gitignore
├── modules/
│   ├── bigquery/             # BigQuery dataset resource
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── firestore/            # Firestore database resource
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/                  # IAM role bindings (for_each on roles list)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/
    │   ├── backend.tf        # GCS state bucket (fantasy-br-tfstate-dev)
    │   ├── providers.tf      # Terraform + Google provider versions
    │   ├── main.tf           # Wires modules together
    │   ├── variables.tf      # Typed input variables
    │   ├── terraform.tfvars  # Environment-specific values
    │   └── outputs.tf
    ├── demo/                 # Same structure as dev
    └── prod/                 # Same structure as dev
```

```bash
uv run terraform -chdir=infra/envs/dev init
uv run terraform -chdir=infra/envs/dev plan -out=tfplan
uv run terraform -chdir=infra/envs/dev apply tfplan
```

IAM bindings are managed via the `iam` module. The service account (`service_account_email` variable, default `github-actions@fantasy-br.iam.gserviceaccount.com`) is granted:

| Role                        | Purpose                                    |
| --------------------------- | ------------------------------------------ |
| `roles/datastore.owner`     | Firestore database creation and read/write |
| `roles/bigquery.dataViewer` | BigQuery SELECT for dbt mart queries       |
| `roles/bigquery.jobUser`    | BigQuery job execution                     |

### Data Pipeline

Raw data is loaded from the Cartola FC API daily by `data-refresh.yaml` and stored in BigQuery
(`raw_players_etl`, `raw_clubs`, `raw_positions`).
The full championship schedule (previous and current season) is loaded from the
football-data.org API into `raw_schedule`.
Historical season data (2025, 2026) is stored as dbt seeds.

### dbt Project (`src/dbt/`)

```
src/dbt/
├── macros/
│   ├── shrink_blend.sql             # shrinkage blending for baseline points
│   ├── scouting_enrichment.sql      # generates z-score + DVS enrichment CTEs
│   ├── stats_by_round.sql           # position/general stat benchmarks
│   ├── z_score_position.sql
│   ├── z_score_general.sql
│   └── dvs.sql
├── models/
│   ├── sources.yml                  # raw BigQuery source table definitions
│   ├── staging/                     # stg_players, stg_clubs, stg_schedule, stg_positions
│   ├── intermediate/
│   │   ├── general/                 # int_matches, int_players, int_baseline, int_home_away,
│   │   │                            #   int_round_by_round, int_edge_cases, int_ga_dependency
│   │   ├── scouting/                # int_sct_*_stats (7 models, one per time window)
│   │   ├── start_or_sit/            # int_map_mpap, int_ewm_form, int_distribution_stats,
│   │   │                            #   int_map_score, int_poe
│   │   └── market_valuation/        # int_replacement_levels, int_form_trend, int_regression,
│   │                                #   int_schedule_strength
│   ├── scouting/                    # sct_last_1, sct_last_5, sct_last_5_home, sct_last_5_away,
│   │                                #   sct_last_10, sct_this_season, sct_last_season
│   ├── start_or_sit/                # ss_main, ss_map_breakdown, ss_mpap_debug, ss_home_away,
│   │                                #   ss_distribution, ss_round_by_round, ss_edge_cases
│   └── market_valuation/            # mv_main, mv_par_breakdown, mv_stabilized, mv_form_trend,
│                                    #   mv_regression, mv_value_profile, mv_schedule_strength,
│                                    #   mv_round_by_round
├── seeds/
│   ├── raw_players_legacy_2025.csv
│   ├── raw_players_legacy_2026.csv
│   ├── raw_scout_points.csv         # scout code to points mapping
│   └── raw_club_mapping.csv         # football-data.org TLA to Cartola club ID mapping
├── dbt_project.yml                  # staging=view, intermediate=view, marts=table
└── profiles.yml                     # local/dev/demo/prod profile definitions
```

#### Materialization Strategy

| Layer            | Type  | Notes                                  |
| ---------------- | ----- | -------------------------------------- |
| staging          | view  | Thin wrappers over raw source tables   |
| intermediate     | view  | Business logic and transformations     |
| scouting         | table | Mart: scouting rankings by time window |
| start_or_sit     | table | Mart: MAP projections and diagnostics  |
| market_valuation | table | Mart: PAR, stabilized mean, regression |

#### Key Intermediate Models

**General:**

- `int_matches` — maps football-data.org schedule to Cartola club IDs via `raw_club_mapping` seed
- `int_players` — base enriched player data per round (scout per-round deltas, opponent, is_home, base_round excludes G/A/CV/GC)
- `int_baseline` — stabilized mean via shrinkage blending (this + last season, k=5)
- `int_home_away` — home/away averages, delta, multiplier
- `int_round_by_round` — season 2026 round-level data with opponent name
- `int_edge_cases` — per-player data quality flags
- `int_ga_dependency` — goal + assist share of total points

**Start or Sit (MAP = Matchup Adjusted Projection):**

- `int_map_mpap` — matchup-adjusted points allowed per position (blended seasons, k=5)
- `int_ewm_form` — EWM form with multiplier clamped 0.8–1.2
- `int_distribution_stats` — P20/P50/P80, CV, consistency rating, boom/bust rates
- `int_map_score` — final MAP = baseline × form_mult × venue_mult × mpap_mult
- `int_poe` — PoE (points over expected): avg_poe_season and avg_poe_last_5 (actual pts minus MAP projection)

**Market Valuation:**

- `int_replacement_levels` — position-specific percentile replacement level + depth flag (DEEP/MODERATE/SCARCE)
- `int_form_trend` — last-3, last-5, EWM averages, trend ratios, form bucket (UP/FLAT/DOWN)
- `int_regression` — regression_score = perf_gap × (1+ga_share) × (1/consistency); signals SELL_HIGH/BUY_LOW/NEUTRAL
- `int_schedule_strength` — avg blended MPAP across upcoming opponents per player: overall (next 10), home (next 5 home), away (next 5 away); materialized as view due to CTE complexity

### Streamlit App (`src/app/`)

| Page             | Mart models used                                                                                                                  |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Scouting         | sct_last_1, sct_last_5, sct_last_5_home, sct_last_5_away, sct_last_10, sct_this_season, sct_last_season                           |
| Start or Sit     | ss_main, ss_map_breakdown, ss_mpap_debug, ss_home_away, ss_distribution, ss_round_by_round, ss_edge_cases                         |
| Market Valuation | mv_main, mv_par_breakdown, mv_stabilized, mv_form_trend, mv_regression, mv_value_profile, mv_schedule_strength, mv_round_by_round |
| Squad and Team   | Firestore only (user_squads, user_teams, user_opponent_squads, user_opponent_teams — no mart models)                              |
| Trade Simulator  | mv_main (PAR values only — no new mart models)                                                                                    |
| Matchup Preview  | ss_main (MAP scores for Team), mv_main (PAR for Squad) and Firestore (user and opponent squads/teams)                             |

Each mart has a dedicated loader in `utils.py` (e.g., `load_ss_main()`, `load_mv_regression()`).
Add new loaders there when adding new mart models.

All pages except Squad and Team have a **My Squad** sidebar toggle (`filter_my_squad`) that filters displayed players to the user's persisted squad (Firestore `user_squads` collection). The toggle defaults to off (show all players). Squad management (add/remove) is only available in the Squad and Team page.

## Dependencies and Package Management

```toml
[project.optional-dependencies]
app = ["streamlit", "google-cloud-bigquery", "google-cloud-firestore", "db-dtypes", "Authlib"]
dbt = ["dbt-bigquery"]
tests = ["ruff", "pytest", "pytest-xdist", "sqlfluff", "sqlfluff-templater-dbt"]
```

`uv sync --all-extras` installs all extras. Use `uv sync --extra <name>` for a subset.

## Script Aliases

All commands run from the repo root:

```bash
uv run app             # Start the Streamlit app
uv run dbt <args>      # Run any dbt command from src/dbt/ (e.g., uv run dbt build)
uv run lint-sql        # Lint all dbt SQL with SQLFluff
uv run format-sql      # Auto-fix all dbt SQL with SQLFluff
uv run lint-app        # Lint all app Python with ruff
uv run format-app      # Auto-fix and format all app Python with ruff
```

## Development Workflow & Commands

### Python Linting and Formatting

```bash
uv run lint-app        # ruff check src/app/
uv run format-app      # ruff check --fix src/app/ && ruff format src/app/
```

### SQL Linting and Formatting

```bash
uv run lint-sql        # sqlfluff lint src/dbt/
uv run format-sql      # sqlfluff fix src/dbt/ --force
```

### dbt

```bash
uv run dbt debug                     # verify connection
uv run dbt seed                      # load historical seeds
uv run dbt run                       # run all models
uv run dbt run --select stg_players  # run specific model
uv run dbt run --select +ss_main     # run with upstream deps
uv run dbt build                     # seeds + models + tests
uv run dbt test                      # run schema tests
uv run dbt run --full-refresh        # rebuild all tables
uv run dbt run --target demo         # target specific environment
```

After making dbt changes, always run `uv run dbt build` to verify.

### Testing

```bash
uv run --env-file .env pytest tests/                          # all tests
uv run --env-file .env pytest tests/ -n auto                  # parallel
uv run --env-file .env pytest tests/test_foo.py::test_bar     # single test
```

Do not use mocks.

### Streamlit App

```bash
uv run app    # runs at http://localhost:8501
```

Ensure `src/app/.streamlit/secrets.toml` has `gcp_service_account` credentials and `allowed_emails` list:

```toml
[auth]
...
allowed_emails = ["felipediasmassa97@gmail.com", "felipediasmassa97@poli.ufrj.br"]
```

Users not in the `allowed_emails` list are shown an "Access denied" message after Google sign-in. If the key is missing or empty, all authenticated users are allowed (open access).

To onboard new users:

- Access [Streamlit Cloud](https://share.streamlit.io/)
- Go to `fantasy-br`'s settings
- Select Secrets tab
- Add the new user email in `allowed_emails` list

## CI/CD Workflows

| File                         | Trigger            | Jobs                                                                 |
| ---------------------------- | ------------------ | -------------------------------------------------------------------- |
| `data-refresh.yaml`          | Daily 3 AM UTC     | Load Cartola API + football-data.org schedule → dbt build (all envs) |
| `implementation.yaml`        | Push to `main`     | infra + dbt: dev → demo → prod                                       |
| `development.yaml`           | Push to non-`main` | infra + dbt: dev only                                                |
| `reusable-infra-deploy.yaml` | Called by above    | Terraform plan and apply                                             |
| `reusable-dbt-build.yaml`    | Called by above    | `dbt build`                                                          |

## Common Tasks

### Add a new mart model

1. Create SQL in the appropriate `src/dbt/models/` subfolder
2. Add a loader function in `src/app/utils.py`
3. Add a tab renderer in the relevant page
4. Run `uv run dbt build --select +new_model`
5. Run `uv run lint-sql && uv run format-sql`

### Update historical data

1. Add/update CSVs in `legacy/{year}/`
2. Update `stg_players.sql` if column structure changed
3. Run `uv run dbt build`

### SQLFluff notes

- Scout field column names (e.g., `scout_G`, `avg_FT`) are uppercase — do not rename to lowercase
- The `scouting_enrichment`, `shrink_blend`, and `shrink_weight` macros have jinja stubs in `pyproject.toml` so SQLFluff can parse models without running dbt locally
