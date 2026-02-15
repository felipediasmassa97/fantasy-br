output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.fantasy_br.dataset_id
}

output "dataset_self_link" {
  description = "BigQuery dataset self link"
  value       = google_bigquery_dataset.fantasy_br.self_link
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}
