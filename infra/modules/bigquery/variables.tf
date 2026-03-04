variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID (e.g. fdmdev_fantasy_br)"
  type        = string
}

variable "description" {
  description = "Human-readable description for the dataset"
  type        = string
}

variable "location" {
  description = "BigQuery dataset location"
  type        = string
}

variable "labels" {
  description = "Labels to attach to the dataset"
  type        = map(string)
  default     = {}
}
