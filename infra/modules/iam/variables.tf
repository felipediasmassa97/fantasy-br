variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account to grant roles to"
  type        = string
}

variable "roles" {
  description = "List of IAM roles to grant to the service account"
  type        = list(string)
}
