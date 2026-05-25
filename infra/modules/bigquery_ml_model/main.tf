# =============================================================================
# BigQuery ML Model — xgb_points_prediction
#
# Manages the BigQuery ML model lifecycle via `bq` CLI.
#
# Terraform CANNOT create BigQuery ML models natively.
# Instead we use a null_resource + local-exec to run the CREATE MODEL DDL.
#
# RETRAIN TRIGGERS (any of):
#   1. training SQL content changes      (filemd5 of create_bqml_model.sql)
#   2. features SQL content changed     (filemd5 of ml_training_features.sql)
#   3. training query OUTPUT changed    (hash of query result set)
#      → computed at apply time by pre-step provisioner, stored in /tmp/bqml_state.json
#      → null_resource trigger includes filemd5 of the state file
#
# NOTE: The destroy provisioner reads dataset/project from the local state file
# to avoid referencing Terraform variables (which are unavailable during destroy).
# =============================================================================

terraform {
  required_version = ">= 1.0"
}

data "terraform_remote_state" "infra" {
  backend = "gcs"
  config {
    bucket = "fantasy-br-tfstate-${var.environment}"
    prefix = "envs/${var.environment}"
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Validate bq CLI is available before attempting CREATE MODEL
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
# Local file to persist the previous training query output hash.
# Used to detect when training data has changed so we re-train.
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
    state_file_content   = filemd5("/tmp/bqml_model_state.json")
  }

  depends_on = [
    data.external.validate_bq,
    google_bigquery_dataset.existing_dataset,
    local_file.bqml_state,
  ]

  # ── Pre-step: compute hash of training query output ──────────────────────
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail

      STATE_FILE="/tmp/bqml_model_state.json"
      FEATURES_FILE="${var.ml_training_features_path}"

      echo "==> Computing training query output hash..."

      # Extract inline features query from the training SQL
      FEATURES_SQL=$(sed -n '/WITH/,/training_data AS (/p' "${var.training_query_path}" | head -n -1)

      # Run the features query and compute sha256 of the result set
      RESULT_HASH=$(bq query --nouse_legacy_sql --use_legacy_sql=false \
        --format=json \
        --max_rows=100000 \
        "SELECT * FROM (${FEATURES_SQL}) ORDER BY 1,2" 2>/dev/null \
        | sha256sum | cut -d' ' -f1)

      echo "    Result hash: ${RESULT_HASH}"

      PREV_SQL_HASH=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('sql_hash','none'))")
      PREV_FEATURES_HASH=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('features_hash','none'))")
      PREV_RESULT_HASH=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('result_hash','none'))")

      CURRENT_SQL_HASH=$(sha256sum "${var.training_query_path}" | cut -d' ' -f1)
      CURRENT_FEATURES_HASH=$(sha256sum "${FEATURES_FILE}" | cut -d' ' -f1)

      SQL_CHANGED=$([ "${PREV_SQL_HASH}" != "${CURRENT_SQL_HASH}" ] && echo "yes" || echo "no")
      FEATURES_CHANGED=$([ "${PREV_FEATURES_HASH}" != "${CURRENT_FEATURES_HASH}" ] && echo "yes" || echo "no")
      RESULT_CHANGED=$([ "${PREV_RESULT_HASH}" != "${RESULT_HASH}" ] && echo "yes" || echo "no")

      echo "    SQL changed: ${SQL_CHANGED}"
      echo "    Features changed: ${FEATURES_CHANGED}"
      echo "    Result changed: ${RESULT_CHANGED}"

      RETRAIN_NEEDED="no"
      if [ "${SQL_CHANGED}" == "yes" ] || [ "${FEATURES_CHANGED}" == "yes" ] || [ "${RESULT_CHANGED}" == "yes" ]; then
        RETRAIN_NEEDED="yes"
        echo "    Retrain will be triggered."
      else
        echo "    No retrain needed — model is up to date."
      fi

      python3 -c "
import json
d = {
    'sql_hash': '${CURRENT_SQL_HASH}',
    'features_hash': '${CURRENT_FEATURES_HASH}',
    'result_hash': '${RESULT_HASH}',
    'retrain_needed': '${RETRAIN_NEEDED}',
    'project_id': '${var.project_id}',
    'dataset_id': '${var.dataset_id}',
    'model_name': '${var.model_name}'
}
with open('${STATE_FILE}', 'w') as f:
    json.dump(d, f)
      "

      echo "    State file updated."
    EOF
  }

  # ── Main step: run CREATE MODEL ──────────────────────────────────────────
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail

      PROJECT="${var.project_id}"
      DATASET="${var.dataset_id}"
      MODEL="${var.model_name}"
      SQL_FILE="${var.training_query_path}"
      STATE_FILE="/tmp/bqml_model_state.json"

      RETRAIN_NEEDED=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['retrain_needed'])" 2>/dev/null || echo "yes")

      if [ "${RETRAIN_NEEDED}" != "yes" ]; then
        echo "    No retrain needed — skipping CREATE MODEL."
        exit 0
      fi

      echo "==> Checking if BigQuery ML model '${MODEL}' exists..."
      if bq ls "${PROJECT}:${DATASET}.${MODEL}" > /dev/null 2>&1; then
        echo "    Model exists — deleting old version for clean retrain..."
        bq rm -f "${PROJECT}:${DATASET}.${MODEL}"
      fi

      echo "==> Substituting \${DATASET} in training SQL..."
      sed_cmd="s/\\\${DATASET}/${DATASET}/g"
      SQL_CONTENT=$(cat "${SQL_FILE}" | sed "${sed_cmd}")

      echo "==> Registering BigQuery ML model..."
      echo "${SQL_CONTENT}" | bq query --nouse_legacy_sql --use_legacy_sql=false --dataset_id="${DATASET}"

      echo "==> Verifying model registration..."
      bq show -model "${PROJECT}:${DATASET}.${MODEL}"

      echo "    ✅ Model '${MODEL}' registered successfully."
    EOF
  }

  # ── Destroy: drop the model on `terraform destroy` ─────────────────────
  # Reads project/dataset from state file (vars unavailable during destroy).
  # ─────────────────────────────────────────────────────────────────────────
  provisioner "local-exec" {
    when   = destroy
    command = <<-EOF
      set -euo pipefail
      STATE_FILE="/tmp/bqml_model_state.json"
      if [ -f "${STATE_FILE}" ]; then
        PROJECT=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['project_id'])" 2>/dev/null)
        DATASET=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['dataset_id'])" 2>/dev/null)
        MODEL=$(python3 -c "import json; print(json.load(open('${STATE_FILE}'))['model_name'])" 2>/dev/null)
      fi
      # Fallback if state file is missing (e.g. first destroy)
      PROJECT="${PROJECT:-${var.project_id}}"
      DATASET="${DATASET:-${var.dataset_id}}"
      MODEL="${MODEL:-${var.model_name}}"
      echo "==> Dropping BigQuery ML model '${MODEL}' from ${PROJECT}:${DATASET}..."
      bq rm -f "${PROJECT}:${DATASET}.${MODEL}" || true
      echo "    ✅ Model dropped."
    EOF
  }
}

# ────────────────────────────────────────────────────────────────────────────
# Reference the existing dataset (must already exist from infra module)
# ────────────────────────────────────────────────────────────────────────────
data "google_bigquery_dataset" "existing_dataset" {
  dataset_id = var.dataset_id
  project    = var.project_id
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