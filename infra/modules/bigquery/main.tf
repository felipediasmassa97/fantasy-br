resource "google_bigquery_dataset" "this" {
  project     = var.project_id
  dataset_id  = var.dataset_id
  description = var.description
  location    = var.location
  labels      = var.labels

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
