resource "google_bigquery_dataset" "fantasy_br" {
  dataset_id  = local.dataset_id
  description = "Fantasy BR dataset for ${var.environment} environment"
  location    = var.gcp_region

  labels = {
    environment = var.environment
    project     = "fantasy-br"
  }

  # Free tier: No expiration on tables by default
  # default_table_expiration_ms = null

  # Access control - project-level defaults
  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }
}
