output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = module.bigquery.dataset_id
}

output "dataset_self_link" {
  description = "BigQuery dataset self link"
  value       = module.bigquery.self_link
}

output "firestore_database" {
  description = "Firestore database name"
  value       = module.firestore.database_name
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}
