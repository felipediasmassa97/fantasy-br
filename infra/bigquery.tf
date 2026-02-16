resource "google_bigquery_dataset" "fantasy_br" {
  dataset_id  = local.dataset_id
  description = "Fantasy BR dataset for ${var.environment} environment"
  location    = var.gcp_region

  labels = {
    environment = var.environment
    project     = "fantasy-br"
  }

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
