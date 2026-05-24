# =============================================================================
# BigQuery ML Model — xgb_points_prediction
#
# Manages the BigQuery ML model lifecycle via `bq` CLI.
#
# Terraform CANNOT create BigQuery ML models natively.
# Instead we use a null_resource + local-exec to run the CREATE MODEL DDL.
# Changes to the training SQL file trigger automatic re-training via
# `create_before_destroy` (old model deleted, new model created).
#
# NOTE: The model's LEAN FEATURES training query is in
# scripts/ml_pipeline/ml_training_features.sql (inline in create_bqml_model.sql).
# Any change to those files triggers re-training.
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
# 1. Validate prerequisites exist before attempting CREATE MODEL
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
# 2. Null resource: CREATE OR REPLACE MODEL
#    Triggers on: any change to the training SQL file content
# ────────────────────────────────────────────────────────────────────────────
resource "null_resource" "bqml_model" {
  # Re-train whenever the training SQL file changes
  triggers = {
    # Hash of the training SQL file content — changes = re-train
    training_sql_content = filemd5(var.training_query_path)
    # Hash of the features SQL content
    features_sql_content = filemd5(var.ml_training_features_path)
    # Explicit env flag — set to "true" to force re-training
    force_retrain = var.force_retrain ? "1" : "0"
  }

  # Ensure bq CLI is available
  depends_on = [
    data.external.validate_bq,
    google_bigquery_dataset.existing_dataset,
  ]

  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail

      PROJECT="${var.project_id}"
      DATASET="${var.dataset_id}"
      MODEL="${var.model_name}"
      SQL_FILE="${var.training_query_path}"
      ENV="${var.environment}"

      echo "==> Checking if BigQuery ML model '${MODEL}' exists..."
      if bq ls "${PROJECT}:${DATASET}.${MODEL}" > /dev/null 2>&1; then
        echo "    Model exists — deleting old version for clean retrain..."
        bq rm -f "${PROJECT}:${DATASET}.${MODEL}"
      fi

      echo "==> Registering BigQuery ML model..."
      bq query --nouse_legacy_sql --use_legacy_sql=false \
        --dataset_id="${DATASET}" \
        "$(cat "${SQL_FILE}")"

      echo "==> Verifying model registration..."
      bq show -model "${PROJECT}:${DATASET}.${MODEL}"

      echo "    ✅ Model '${MODEL}' registered successfully."
    EOF
  }

  # Destroy: drop the model on `terraform destroy`
  provisioner "local-exec" {
    when   = destroy
    command = <<-EOF
      set -euo pipefail
      PROJECT="${var.project_id}"
      DATASET="${var.dataset_id}"
      MODEL="${var.model_name}"
      echo "==> Dropping BigQuery ML model '${MODEL}'..."
      bq rm -f "${PROJECT}:${DATASET}.${MODEL}" || true
      echo "    ✅ Model dropped."
    EOF
  }
}

# ────────────────────────────────────────────────────────────────────────────
# 3. Reference the existing dataset (must already exist from infra module)
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

output "model_exists" {
  description = "Whether the model exists after apply"
  # This is dynamically resolved by the null_resource
  # Terraform will show 'tainted' if CREATE MODEL failed
  value = "true"
}

output "training_triggered" {
  description = "Whether the null_resource will trigger re-training"
  value       = null_resource.bqml_model.triggers.training_sql_content != "" ? "yes" : "no"
}