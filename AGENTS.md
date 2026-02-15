## Tech Stack

- Language: Python 3.13
- Infrastructure: `terraform` for Google BigQuery
- Data Transformation: `dbt`
- Web Application: `streamlit`
- Package Management: `uv`
- Testing: `pytest` for unit/integration tests
- Linting & Formatting: `ruff`

## Project Structure

- `src/`: The source code.
  - `app/`: Streamlit app for user interaction with data.
  - `dbt/`: Data project for ELT on top of Cartola API.
  - `legacy/`: Legacy Jupyter notebooks and generated reports in Excel.
- `infra/`: Terraform code for defining the application's Google BigQuery infrastructure.
- `tests/`: Unit and integration tests for `pytest`.

## Development Workflow & Commands

- Do not commit any changes unless explicitly asked to do so.
- Avoid fallbacks unless absolutely necessary. Throw errors instead.
- Do not use emojis.
- Use single-line docstrings for all functions, methods, and classes.
- Do not use generic try/except blocks to capture and suppress errors; let exceptions propagate naturally.

### Linting and Formatting

This project uses `ruff` for all linting and formatting. Always run the fixer after making changes.

- To fix all linting issues, run the following command. You may need to run it multiple times until no issues remain. `uvx ruff check --fix`
- When tasked with fixing linting issues, run the command in a loop until the output indicates that all issues are resolved.
- To fix all formatting issues, run the following command. `uvx ruff format`.

### Google BigQuery Infrastructure

Infrastructure is managed with Terraform.

- To initialize Terraform: `cd infra && terraform init`
- To deploy for an environment: `ENVIRONMENT=dev && terraform apply -var-file=envs/${ENVIRONMENT}.tfvars`

### dbt

The dbt project is located in `src/dbt/`. All commands must be run from that directory.

- To verify connection: `cd src/dbt && uv run dbt debug`
- To load seeds: `uv run dbt seed`
- To run all models: `uv run dbt run`
- To run a specific model: `uv run dbt run --select <model_name>`
- To run tests: `uv run dbt test`
- To full refresh: `uv run dbt run --full-refresh`

### Testing

Tests are run using `pytest`. Tests are located in the `tests/` directory.

- Do not use mocks in tests.
- To run a single test locally: `uv run --env-file .env pytest <PATH>::<TEST> --log-cli-level=INFO`
- To run multiple tests in a file or directory locally (in parallel): `uv run --env-file .env pytest <PATH> -n auto`
