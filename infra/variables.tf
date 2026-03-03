variable "environment" {
  description = "Environment name (dev, demo, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "demo", "prod"], var.environment)
    error_message = "Environment must be one of: dev, demo, prod"
  }
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for BigQuery dataset"
  type        = string
  default     = "US"
}

variable "firestore_location" {
  description = "GCP location for Firestore database (e.g., nam5 for US multi-region)"
  type        = string
  default     = "nam5"
}

variable "app_service_account_email" {
  description = "Email of the GCP service account used by the app and CI/CD pipelines"
  type        = string
  default     = "github-actions@fantasy-br.iam.gserviceaccount.com"
}
