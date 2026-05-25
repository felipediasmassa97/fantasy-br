# =============================================================================
# BigQuery ML Model — xgb_points_prediction
#
# Manages the BigQuery ML model lifecycle via `bq` CLI.
# Terraform CANNOT create BigQuery ML models natively — use null_resource +
# local-exec with environment variables for config (avoids all interpolation
# complexity in command strings).
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
# Local file to persist training state and destroy-time config
# ────────────────────────────────────────────────────────────────────────────
resource "local_file" "bqml_state" {
  filename = "/tmp/bqml_model_state.json"
  content  = jsonencode({
    sql_hash      = filemd5("${path.module}/../../../scripts/ml_pipeline/create_bqml_model.sql")
    features_hash = filemd5("${path.module}/../../../scripts/ml_pipeline/ml_training_features.sql")
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
    training_sql_content = filemd5("${path.module}/../../../scripts/ml_pipeline/create_bqml_model.sql")
    features_sql_content = filemd5("${path.module}/../../../scripts/ml_pipeline/ml_training_features.sql")
  }

  depends_on = [
    data.external.validate_bq,
    data.google_bigquery_dataset.existing_dataset,
    local_file.bqml_state,
  ]

  # ── Pre-step: compute hash of training query output ──────────────────────
  provisioner "local-exec" {
    command = "bash ${path.module}/../../../scripts/ml_pipeline/bqml_prestep.sh"
    environment = {
      TF_PROJECT_ID    = var.project_id
      TF_DATASET        = var.dataset_id
      TF_MODEL          = var.model_name
      TF_SQL_FILE       = "${path.module}/../../../scripts/ml_pipeline/create_bqml_model.sql"
      TF_FEATURES_FILE  = "${path.module}/../../../scripts/ml_pipeline/ml_training_features.sql"
      TF_STATE_FILE     = local_file.bqml_state.filename
    }
  }

  # ── Main step: run CREATE MODEL ──────────────────────────────────────────
  provisioner "local-exec" {
    command = "bash ${path.module}/../../../scripts/ml_pipeline/bqml_create_model.sh"
    environment = {
      TF_PROJECT_ID    = var.project_id
      TF_DATASET        = var.dataset_id
      TF_MODEL          = var.model_name
      TF_SQL_FILE       = "${path.module}/../../../scripts/ml_pipeline/create_bqml_model.sql"
      TF_STATE_FILE     = local_file.bqml_state.filename
    }
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
    command = "bash ${path.module}/../../../scripts/ml_pipeline/bqml_destroy.sh"
    environment = {
      TF_STATE_FILE = local_file.bqml_state.filename
    }
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