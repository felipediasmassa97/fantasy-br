# =============================================================================
# BigQuery ML Model — xgb_points_prediction
#
# Manages the lifecycle of the XGBoost model in BigQuery ML.
#
# NOTE: Terraform manages the model metadata and IAM. The actual model
# training (CREATE MODEL DDL) is executed by a GitHub Actions workflow
# step after `terraform apply`, since BigQuery ML uses DDL for model
# creation rather than a native Terraform resource.
# =============================================================================

variable "model_name" {
  description = "BigQuery ML model name"
  type        = string
  default     = "xgb_points_prediction"
}

variable "dataset_id" {
  description = "BigQuery dataset where the model lives"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment (dev, demo, prod)"
  type        = string
}

variable "training_query_path" {
  description = "Path to the SQL file with the CREATE MODEL DDL"
  type        = string
  default     = "scripts/ml_pipeline/create_bqml_model.sql"
}

variable "ml_training_features_path" {
  description = "Path to the SQL file with the lean features training query"
  type        = string
  default     = "scripts/ml_pipeline/ml_training_features.sql"
}

variable "labels" {
  description = "Labels to attach to model resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Output: model reference for downstream use
# =============================================================================
output "model_reference" {
  description = "Full model reference: project.dataset.model_name"
  value       = "${var.project_id}.${var.dataset_id}.${var.model_name}"
}

output "model_name" {
  description = "Model name"
  value       = var.model_name
}

output "dataset_id" {
  description = "Dataset ID"
  value       = var.dataset_id
}