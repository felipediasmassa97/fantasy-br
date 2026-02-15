# Fantasy BR

Fantasy football data project for Brazilian leagues using Google BigQuery.

## Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) for Python package management
- [Terraform](https://www.terraform.io/downloads) >= 1.0 for infrastructure
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) for GCP authentication

## Infrastructure

See [infra/README.md](infra/README.md) for setup and deployment instructions.

## dbt

The dbt project is located in `src/dbt/`. All dbt commands should be run from that directory.

### Setup

```bash
cd src/dbt

# Authenticate with GCP (required for local development)
gcloud auth application-default login

# Verify connection
uv run dbt debug --profiles-dir .
```

### Running dbt

```bash
cd src/dbt

# Load seed data
uv run dbt seed --profiles-dir .

# Run all models
uv run dbt run --profiles-dir .

# Run specific model
uv run dbt run --profiles-dir . --select model_name

# Run tests
uv run dbt test --profiles-dir .

# Generate documentation
uv run dbt docs generate --profiles-dir .
uv run dbt docs serve --profiles-dir .

# Full refresh (rebuild tables)
uv run dbt run --profiles-dir . --full-refresh
```

### Profiles

- **local** (default): Uses OAuth for local development
- **dev**: Uses service account for cloud deployment

To use a specific profile:

```bash
uv run dbt run --profiles-dir . --target dev
```

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
