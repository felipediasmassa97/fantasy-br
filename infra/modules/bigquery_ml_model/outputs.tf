output "model_reference" {
  description = "Full BigQuery ML model reference (project.dataset.model_name)"
  value       = module.bqml_model.model_reference
}

output "model_name" {
  description = "BigQuery ML model name"
  value       = module.bqml_model.model_name
}

output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = module.bqml_model.dataset_id
}