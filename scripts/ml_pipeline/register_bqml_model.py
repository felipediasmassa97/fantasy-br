#!/usr/bin/env python3
"""
Register BigQuery ML Model: xgb_points_prediction

This script:
1. Loads the XGBoost model config to validate features
2. Assembles lean training features from existing int_* models in BigQuery
3. Creates the BigQuery ML BOOSTED_TREE_REGRESSOR model
4. Validates the model registration

Usage:
    python register_bqml_model.py [--dry-run] [--project PROJECT]

Prerequisites:
    - Google Cloud authentication (gcloud auth, service account, or workload identity)
    - BigQuery API enabled
    - Dataset: fdmdev_fantasy_br
"""

import argparse
import json
import sys
from datetime import datetime

# Try to import google.cloud.bigquery, install if missing
try:
    from google.cloud import bigquery
except ImportError:
    print("Installing google-cloud-bigquery...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "google-cloud-bigquery", "-q"])
    from google.cloud import bigquery


# =============================================================================
# Configuration
# =============================================================================

PROJECT_ID = "fantasy-br"
DATASET_ID = "fdmdev_fantasy_br"
MODEL_NAME = "xgb_points_prediction"
MODEL_URI = f"{PROJECT_ID}.{DATASET_ID}.{MODEL_NAME}"

# Lean feature set (15 features based on XGBoost importance)
FEATURES = [
    "baseline_pts",
    "ewm_pts",
    "form_multiplier",
    "mpap_ratio",
    "pts_allowed_this",
    "is_home_game",
    "position_enc",
    "player_pts_avg_this_season",
    "availability_this_season",
    "dist_pts_avg",
    "bust_rate",
    "boom_rate",
    "avg_scout_g",
    "avg_scout_a",
    "home_away_delta",
    "par_estimate",
]
LABEL = "target_pts_round"

# Model hyperparameters (from model_config.json)
HYPERPARAMS = {
    "num_boosted_rounds": 400,
    "max_depth": 4,
    "learning_rate": 0.1,
    "subsample": 0.8,
    "colsample_bytree": 0.8,
    "min_child_weight": 5,
    "l1_reg": 0.1,
    "l2_reg": 1.0,
}


# =============================================================================
# SQL: Training Data Query (assembles features from int_* models)
# =============================================================================

TRAINING_DATA_SQL = """
WITH

base_player_rounds AS (
    SELECT
        pl.player_id,
        pl.round_id,
        pl.pts_round AS target_pts_round,
        pl.is_home AS is_home_game
    FROM `{project}.{dataset}.int_players` pl
    WHERE pl.pts_round IS NOT NULL
      AND pl.round_id BETWEEN 3 AND 16
),

feat_baseline AS (
    SELECT
        b.player_id,
        b.as_of_round_id + 2 AS round_id,
        b.baseline_pts,
        b.player_pts_avg_this_season
    FROM `{project}.{dataset}.int_baseline` b
    INNER JOIN base_player_rounds br
        ON b.player_id = br.player_id
       AND b.as_of_round_id + 2 = br.round_id
),

feat_ewm_form AS (
    SELECT
        e.player_id,
        e.round_id AS as_of_round_id,
        e.ewm_pts,
        e.form_multiplier
    FROM `{project}.{dataset}.int_ewm_form` e
    INNER JOIN base_player_rounds br
        ON e.player_id = br.player_id
       AND e.round_id + 2 = br.round_id
),

feat_mpap AS (
    SELECT
        m.player_id,
        m.as_of_round_id + 2 AS round_id,
        m.mpap_ratio,
        m.mpap_multiplier
    FROM `{project}.{dataset}.int_map_score` m
    INNER JOIN base_player_rounds br
        ON m.player_id = br.player_id
       AND m.as_of_round_id + 2 = br.round_id
),

feat_pts_allowed AS (
    SELECT
        r.player_id,
        r.as_of_round_id + 2 AS round_id,
        r.pts_allowed_this
    FROM `{project}.{dataset}.int_regression` r
    INNER JOIN base_player_rounds br
        ON r.player_id = br.player_id
       AND r.as_of_round_id + 2 = br.round_id
),

feat_distribution AS (
    SELECT
        d.player_id,
        d.as_of_round_id + 2 AS round_id,
        d.bust_rate,
        d.boom_rate,
        d.dist_pts_avg
    FROM `{project}.{dataset}.int_distribution_stats` d
    INNER JOIN base_player_rounds br
        ON d.player_id = br.player_id
       AND d.as_of_round_id + 2 = br.round_id
),

feat_home_away AS (
    SELECT
        h.player_id,
        h.as_of_round_id + 2 AS round_id,
        h.home_away_delta
    FROM `{project}.{dataset}.int_home_away` h
    INNER JOIN base_player_rounds br
        ON h.player_id = br.player_id
       AND h.as_of_round_id + 2 = br.round_id
),

feat_availability AS (
    SELECT
        pl.player_id,
        pl.round_id,
        SAFE_DIVIDE(
            COUNTIF(pl.pts_round IS NOT NULL),
            COUNT(*)
        ) AS availability_this_season
    FROM `{project}.{dataset}.int_players` pl
    INNER JOIN base_player_rounds br
        ON pl.player_id = br.player_id
       AND pl.round_id <= br.round_id - 2
    GROUP BY pl.player_id, pl.round_id
),

feat_scout AS (
    SELECT
        player_id,
        round_id,
        avg_scout_g,
        avg_scout_a,
        avg_scout_ff,
        avg_scout_fs
    FROM `{project}.{dataset}.int_players`
),

feat_position AS (
    SELECT DISTINCT
        player_id,
        round_id,
        CASE position_short
            WHEN 'GK' THEN 0
            WHEN 'FB' THEN 1
            WHEN 'CB' THEN 2
            WHEN 'MD' THEN 3
            WHEN 'AT' THEN 4
            ELSE 3
        END AS position_enc
    FROM `{project}.{dataset}.int_players`
),

feat_par AS (
    SELECT
        r.player_id,
        r.as_of_round_id + 2 AS round_id,
        r.replacement_level
    FROM `{project}.{dataset}.int_replacement_levels` r
    INNER JOIN base_player_rounds br
        ON r.player_id = br.player_id
       AND r.as_of_round_id + 2 = br.round_id
),

training_data AS (
    SELECT
        br.player_id,
        br.round_id,
        br.target_pts_round,

        COALESCE(baseline.baseline_pts, 3.4785)        AS baseline_pts,
        COALESCE(ewm.ewm_pts, 2.9339)                  AS ewm_pts,
        COALESCE(ewm.form_multiplier, 0.8694)          AS form_multiplier,
        COALESCE(mpap.mpap_ratio, 0.9207)             AS mpap_ratio,
        COALESCE(pts_allowed.pts_allowed_this, 2.7646) AS pts_allowed_this,
        COALESCE(CAST(br.is_home_game AS INT64), 0)   AS is_home_game,
        COALESCE(pos.position_enc, 3)                  AS position_enc,
        COALESCE(baseline.player_pts_avg_this_season, 3.0) AS player_pts_avg_this_season,
        COALESCE(avail.availability_this_season, 0.714) AS availability_this_season,
        COALESCE(dist.dist_pts_avg, 3.0)              AS dist_pts_avg,
        COALESCE(dist.bust_rate, 0.5)                  AS bust_rate,
        COALESCE(dist.boom_rate, 0.0)                  AS boom_rate,
        COALESCE(scout.avg_scout_g, 0.0)               AS avg_scout_g,
        COALESCE(scout.avg_scout_a, 0.0)               AS avg_scout_a,
        COALESCE(ha.home_away_delta, 0.0)               AS home_away_delta,
        COALESCE(baseline.baseline_pts, 3.4785) - COALESCE(par.replacement_level, 3.5544) AS par_estimate

    FROM base_player_rounds br

    LEFT JOIN feat_baseline baseline
        ON br.player_id = baseline.player_id
       AND br.round_id = baseline.round_id

    LEFT JOIN feat_ewm_form ewm
        ON br.player_id = ewm.player_id
       AND ewm.as_of_round_id + 2 = br.round_id

    LEFT JOIN feat_mpap mpap
        ON br.player_id = mpap.player_id
       AND br.round_id = mpap.round_id

    LEFT JOIN feat_pts_allowed pts_allowed
        ON br.player_id = pts_allowed.player_id
       AND br.round_id = pts_allowed.round_id

    LEFT JOIN feat_distribution dist
        ON br.player_id = dist.player_id
       AND br.round_id = dist.round_id

    LEFT JOIN feat_home_away ha
        ON br.player_id = ha.player_id
       AND br.round_id = ha.round_id

    LEFT JOIN feat_availability avail
        ON br.player_id = avail.player_id
       AND br.round_id = avail.round_id

    LEFT JOIN feat_scout scout
        ON br.player_id = scout.player_id
       AND br.round_id = scout.round_id

    LEFT JOIN feat_position pos
        ON br.player_id = pos.player_id
       AND br.round_id = pos.round_id

    LEFT JOIN feat_par par
        ON br.player_id = par.player_id
       AND br.round_id = par.round_id

    WHERE br.round_id >= 3
)

SELECT
    target_pts_round AS label,
    baseline_pts,
    ewm_pts,
    form_multiplier,
    mpap_ratio,
    pts_allowed_this,
    is_home_game,
    position_enc,
    player_pts_avg_this_season,
    availability_this_season,
    dist_pts_avg,
    bust_rate,
    boom_rate,
    avg_scout_g,
    avg_scout_a,
    home_away_delta,
    par_estimate
FROM training_data
"""

# =============================================================================
# CREATE MODEL Statement
# =============================================================================

CREATE_MODEL_SQL = """
CREATE OR REPLACE MODEL `{project}.{dataset}.{model_name}`
OPTIONS(
    model_type = 'BOOSTED_TREE_REGRESSOR',
    booster_type = 'GBTREE',
    num_boosted_rounds = {num_boosted_rounds},
    max_depth = {max_depth},
    learning_rate = {learning_rate},
    subsample = {subsample},
    colsample_bytree = {colsample_bytree},
    min_child_weight = {min_child_weight},
    l1_reg = {l1_reg},
    l2_reg = {l2_reg},
    early_stop = TRUE,
    min_relative_loss = 0.01,
    input_label_cols = ['label'],
    enable_global_explain = TRUE
)
AS
{training_query}
"""


# =============================================================================
# Main Functions
# =============================================================================

def get_client(project_id: str) -> bigquery.Client:
    """Initialize BigQuery client."""
    return bigquery.Client(project=project_id)


def validate_int_models_exist(client: bigquery.Client, project: str, dataset: str) -> bool:
    """Check that required int_* models exist in BigQuery."""
    required_models = [
        "int_players",
        "int_baseline",
        "int_ewm_form",
        "int_map_score",
        "int_regression",
        "int_distribution_stats",
        "int_home_away",
        "int_replacement_levels",
    ]

    print(f"\n🔍 Validating int_* models in {project}.{dataset}...")
    all_exist = True

    for model in required_models:
        query = f"""
        SELECT table_name
        FROM `{project}.{dataset}.INFORMATION_SCHEMA.TABLES`
        WHERE table_name = '{model}'
        """
        result = client.query(query).result()
        exists = len(list(result)) > 0
        status = "✅" if exists else "❌"
        print(f"  {status} {model}")
        if not exists:
            all_exist = False

    return all_exist


def count_training_rows(client: bigquery.Client, project: str, dataset: str) -> int:
    """Count rows in training dataset to verify data availability."""
    query = TRAINING_DATA_SQL.format(project=project, dataset=dataset)
    query = f"SELECT COUNT(*) as cnt FROM ({query})"
    result = client.query(query).result()
    row = next(result)
    return row["cnt"]


def create_model(client: bigquery.Client, project: str, dataset: str, model_name: str,
                 dry_run: bool = False) -> dict:
    """Create the BigQuery ML model."""
    print(f"\n🚀 Creating model: {project}.{dataset}.{model_name}")

    if dry_run:
        print("   [DRY RUN] Skipping actual model creation")
        return {"status": "dry_run"}

    # Build the CREATE MODEL statement
    formatted_training_sql = TRAINING_DATA_SQL.format(project=project, dataset=dataset)
    create_sql = CREATE_MODEL_SQL.format(
        project=project,
        dataset=dataset,
        model_name=model_name,
        training_query=formatted_training_sql,
        **HYPERPARAMS
    )

    print("   Executing CREATE MODEL statement...")
    job = client.query(create_sql)
    job.result()  # Wait for completion

    return {
        "status": "success",
        "job_id": job.job_id,
        "model_uri": f"{project}.{dataset}.{model_name}"
    }


def validate_model(client: bigquery.Client, model_uri: str) -> dict:
    """Validate model was created and get metadata."""
    print(f"\n✅ Validating model: {model_uri}")

    model_info = client.get_model(model_uri)

    return {
        "model_type": model_info.model_type,
        "etag": model_info.etag,
        "created": model_info.created.isoformat() if model_info.created else None,
        "modified": model_info.modified.isoformat() if model_info.modified else None,
    }


def main():
    parser = argparse.ArgumentParser(description="Register BigQuery ML model")
    parser.add_argument("--project", default=PROJECT_ID, help="GCP project ID")
    parser.add_argument("--dataset", default=DATASET_ID, help="BigQuery dataset ID")
    parser.add_argument("--dry-run", action="store_true", help="Parse SQL without creating model")
    parser.add_argument("--skip-validation", action="store_true", help="Skip int model validation")
    args = parser.parse_args()

    print("=" * 70)
    print("🏈 BigQuery ML Model Registration: xgb_points_prediction")
    print("=" * 70)
    print(f"\nConfig:")
    print(f"  Project:  {args.project}")
    print(f"  Dataset:  {args.dataset}")
    print(f"  Model:    {args.dataset}.xgb_points_prediction")
    print(f"  Features: {len(FEATURES)} (lean feature set)")
    print(f"  Hyperparameters: {HYPERPARAMS}")

    # Initialize client
    client = get_client(args.project)

    # Validate int models exist
    if not args.skip_validation:
        if not validate_int_models_exist(client, args.project, args.dataset):
            print("\n❌ Missing required int_* models. Aborting.")
            sys.exit(1)

    # Count training rows
    print("\n📊 Counting training rows...")
    try:
        row_count = count_training_rows(client, args.project, args.dataset)
        print(f"   Training rows: {row_count:,}")
        if row_count < 1000:
            print("   ⚠️  Low row count. Check int_* models have data.")
    except Exception as e:
        print(f"   ⚠️  Could not count rows: {e}")

    # Create model
    result = create_model(
        client,
        args.project,
        args.dataset,
        MODEL_NAME,
        dry_run=args.dry_run
    )

    if result["status"] == "success":
        print(f"\n✅ Model created successfully!")
        print(f"   URI: {result['model_uri']}")
        print(f"   Job: {result['job_id']}")

        # Validate
        info = validate_model(client, result["model_uri"])
        print(f"\n📋 Model Metadata:")
        print(f"   Type:     {info['model_type']}")
        print(f"   Created:  {info['created']}")
        print(f"   Modified: {info['modified']}")

        print("\n🎯 Model ready for prediction!")
        print(f"   SELECT * FROM ML.PREDICT(MODEL `{result['model_uri']}`, ")
        print(f"       (SELECT ... FROM training_features_sql))")

    elif result["status"] == "dry_run":
        print("\n✅ Dry run completed. No model created.")

    print("\n" + "=" * 70)


if __name__ == "__main__":
    main()