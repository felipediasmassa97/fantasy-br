variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "database_name" {
  description = "Firestore database name"
  type        = string
}

variable "location_id" {
  description = "Firestore database location (e.g. nam5 for US multi-region)"
  type        = string
}

variable "type" {
  description = "Firestore database type"
  type        = string
  default     = "FIRESTORE_NATIVE"
}
