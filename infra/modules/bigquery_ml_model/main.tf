# =============================================================================
# BigQuery ML Model — xgb_points_prediction
#
# Manages the BigQuery ML model lifecycle via `bq` CLI.
# Terraform CANNOT create BigQuery ML models natively — use null_resource +
# local-exec with `$${...}` escaping to prevent Terraform from interpolating
# shell variables before the shell sees them.
#
# RETRAIN TRIGGERS (checked at runtime in pre-step):
#   1. training SQL content changes
#   2. features SQL content changed
#   3. training query OUTPUT changed (hash of query result set)
# =============================================================================

terraform {
  required_version = ">= 1.0"
}

# ────────────────────────────────────────────────────────────────────────────
# Reference the existing dataset
# ────────────────────────────────────────────────────────────────────────────
data "google_bigquery_dataset" "existing_dataset" {
  dataset_id = var.dataset_id
  project    = var.project_id
}

# ────────────────────────────────────────────────────────────────────────────
# Validate bq CLI is available
# ────────────────────────────────────────────────────────────────────────────
data "external" "validate_bq" {
  program = ["bash", "-c", <<-EOF
    if command -v bq > /dev/null 2>&1; then
      echo '{"status":"ok","bq_version":"installed"}'
    else
      echo '{"status":"error","message":"bq CLI not found"}'
    fi
EOF
  ]
}

# ────────────────────────────────────────────────────────────────────────────
# Local file to persist training state and config for destroy provisioner
# ────────────────────────────────────────────────────────────────────────────
resource "local_file" "bqml_state" {
  filename = "/tmp/bqml_model_state.json"
  content  = jsonencode({
    sql_hash      = filemd5(var.training_query_path)
    features_hash = filemd5(var.ml_training_features_path)
    result_hash   = "none"
    project_id    = var.project_id
    dataset_id    = var.dataset_id
    model_name    = var.model_name
  })
}

# ────────────────────────────────────────────────────────────────────────────
# Null resource: CREATE OR REPLACE MODEL
# ────────────────────────────────────────────────────────────────────────────
resource "null_resource" "bqml_model" {
  triggers = {
    training_sql_content = filemd5(var.training_query_path)
    features_sql_content = filemd5(var.ml_training_features_path)
  }

  depends_on = [
    data.external.validate_bq,
    data.google_bigquery_dataset.existing_dataset,
    local_file.bqml_state,
  ]

  # ── Pre-step: compute hash of training query output ──────────────────────
  # $${VAR} escapes Terraform interpolation — shell sees ${VAR} at runtime
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail

      # Use double-dollar to get literal $ for shell variables
      PROJECT="$${var.project_id}"
      DATASET="$${var.dataset_id}"
      MODEL="$${var.model_name}"
      SQL_FILE="$${var.training_query_path}"
      FEATURES_FILE="$${var.ml_training_features_path}"
      STATE_FILE="$${local_file.bqml_state.filename}"

      echo "==> Computing training query output hash..."

      FEATURES_SQL=$(sed -n '/WITH/,/training_data AS (/p' "$${SQL_FILE}" | head -n -1)

      RESULT_HASH=$(bq query --nouse_legacy_sql --use_legacy_sql=false \
        --format=json \
        --max_rows=100000 \
        "SELECT * FROM ($${FEATURES_SQL}) ORDER BY 1,2" 2>/dev/null \
        | sha256sum | cut -d' ' -f1)

      echo "    Result hash: $${RESULT_HASH}"

      PREV_SQL_HASH=$(python3 -c "import json; d=json.load(open('$${STATE_FILE}')); print(d.get('sql_hash','none'))")
      PREV_FEATURES_HASH=$(python3 -c "import json; d=json.load(open('$${STATE_FILE}')); print(d.get('features_hash','none'))")
      PREV_RESULT_HASH=$(python3 -c "import json; d=json.load(open('$${STATE_FILE}')); print(d.get('result_hash','none'))")

      CURRENT_SQL_HASH=$(sha256sum "$${SQL_FILE}" | cut -d' ' -f1)
      CURRENT_FEATURES_HASH=$(sha256sum "$${FEATURES_FILE}" | cut -d' ' -f1)

      SQL_CHANGED=$([ "$${PREV_SQL_HASH}" != "$${CURRENT_SQL_HASH}" ] && echo "yes" || echo "no")
      FEATURES_CHANGED=$([ "$${PREV_FEATURES_HASH}" != "$${CURRENT_FEATURES_HASH}" ] && echo "yes" || echo "no")
      RESULT_CHANGED=$([ "$${PREV_RESULT_HASH}" != "$${RESULT_HASH}" ] && echo "yes" || echo "no")

      echo "    SQL changed: $${SQL_CHANGED}"
      echo "    Features changed: $${FEATURES_CHANGED}"
      echo "    Result changed: $${RESULT_CHANGED}"

      RETRAIN_NEEDED="no"
      if [ "$${SQL_CHANGED}" == "yes" ] || [ "$${FEATURES_CHANGED}" == "yes" ] || [ "$${RESULT_CHANGED}" == "yes" ]; then
        RETRAIN_NEEDED="yes"
        echo "    Retrain will be triggered."
      else
        echo "    No retrain needed — model is up to date."
      fi

      python3 -c "
import json
d = {
    'sql_hash': '$${CURRENT_SQL_HASH}',
    'features_hash': '$${CURRENT_FEATURES_HASH}',
    'result_hash': '$${RESULT_HASH}',
    'retrain_needed': '$${RETRAIN_NEEDED}',
    'project_id': '$${PROJECT}',
    'dataset_id': '$${DATASET}',
    'model_name': '$${MODEL}'
}
with open('$${STATE_FILE}', 'w') as f:
    json.dump(d, f)
"

      echo "    State file updated."
    EOF
  }

  # ── Main step: run CREATE MODEL ──────────────────────────────────────────
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail

      PROJECT="$${var.project_id}"
      DATASET="$${var.dataset_id}"
      MODEL="$${var.model_name}"
      SQL_FILE="$${var.training_query_path}"
      STATE_FILE="$${local_file.bqml_state.filename}"

      RETRAIN_NEEDED=$(python3 -c "import json; print(json.load(open('$${STATE_FILE}'))['retrain_needed'])" 2>/dev/null || echo "yes")

      if [ "$${RETRAIN_NEEDED}" != "yes" ]; then
        echo "    No retrain needed — skipping CREATE MODEL."
        exit 0
      fi

      echo "==> Checking if BigQuery ML model '$${MODEL}' exists..."
      if bq ls "$${PROJECT}:$${DATASET}.$${MODEL}" > /dev/null 2>&1; then
        echo "    Model exists — deleting old version for clean retrain..."
        bq rm -f "$${PROJECT}:$${DATASET}.$${MODEL}"
      fi

      echo "==> Substituting dataset in training SQL..."
      # Hardcode dataset in sed replacement (avoid nested interpolation issues)
      SQL_CONTENT=$(cat "$${SQL_FILE}" | sed "s/DUMMY_DATASET_PLACEHOLDER/$${DATASET}/g")

      echo "==> Registering BigQuery ML model..."
      echo "$${SQL_CONTENT}" | bq query --nouse_legacy_sql --use_legacy_sql=false --dataset_id="$${DATASET}"

      echo "==> Verifying model registration..."
      bq show -model "$${PROJECT}:$${DATASET}.$${MODEL}"

      echo "    Model '$${MODEL}' registered successfully."
    EOF
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Destroy provisioner: separate null resource (no var.* references allowed)
# ────────────────────────────────────────────────────────────────────────────
resource "null_resource" "bqml_model_destroy" {
  triggers = {
    filename = local_file.bqml_state.filename
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${path.module}/scripts/bqml_destroy.sh"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Outputs
# ────────────────────────────────────────────────────────────────────────────
output "model_reference" {
  description = "Full BigQuery ML model reference"
  value       = "${var.project_id}.${var.dataset_id}.${var.model_name}"
}

output "model_name" {
  description = "BigQuery ML model name"
  value       = var.model_name
}

output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = var.dataset_id
}