"""CLI entry points for fantasy-br project scripts."""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run_app() -> None:
    """Run the Streamlit application."""
    result = subprocess.call(
        [sys.executable, "-m", "streamlit", "run", "src/app/main.py", *sys.argv[1:]],
        cwd=str(ROOT),
    )
    sys.exit(result)


def run_dbt() -> None:
    """Run dbt from the dbt project directory, forwarding all arguments."""
    os.chdir(ROOT / "src" / "dbt")
    from dbt.cli.main import cli  # noqa: PLC0415

    sys.argv[0] = "dbt"
    cli()


def lint_sql() -> None:
    """Lint all SQL files in the dbt project using SQLFluff."""
    result = subprocess.call(
        ["sqlfluff", "lint", "src/dbt", *sys.argv[1:]],
        cwd=str(ROOT),
    )
    sys.exit(result)


def format_sql() -> None:
    """Format all SQL files in the dbt project using SQLFluff."""
    result = subprocess.call(
        ["sqlfluff", "fix", "src/dbt", "--force", *sys.argv[1:]],
        cwd=str(ROOT),
    )
    sys.exit(result)


def lint_app() -> None:
    """Lint all Python files in the app project using ruff."""
    result = subprocess.call(
        ["ruff", "check", "src/app", *sys.argv[1:]],
        cwd=str(ROOT),
    )
    sys.exit(result)


def format_app() -> None:
    """Format and auto-fix all Python files in the app using ruff."""
    check = subprocess.call(
        ["ruff", "check", "--fix", "src/app"],
        cwd=str(ROOT),
    )
    fmt = subprocess.call(
        ["ruff", "format", "src/app"],
        cwd=str(ROOT),
    )
    sys.exit(max(check, fmt))
