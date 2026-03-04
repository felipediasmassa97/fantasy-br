variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, demo, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "demo", "prod"], var.environment)
    error_message = "Environment must be one of: dev, demo, prod."
  }
}

variable "dataset_id" {
  description = "BigQuery dataset ID"
  type        = string
}

variable "firestore_location" {
  description = "GCP location for Firestore database (e.g. nam5 for US multi-region)"
  type        = string
}

variable "service_account_email" {
  description = "Email of the GCP service account used by CI/CD and the app"
  type        = string
}
