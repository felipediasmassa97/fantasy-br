module "bigquery" {
  source = "../../modules/bigquery"

  project_id  = var.project_id
  dataset_id  = var.dataset_id
  description = "Fantasy BR dataset for ${var.environment} environment"
  location    = var.region

  labels = {
    environment = var.environment
    project     = "fantasy-br"
  }
}

module "firestore" {
  source = "../../modules/firestore"

  project_id    = var.project_id
  database_name = "fantasy-br-${var.environment}-squads-teams"
  location_id   = var.firestore_location
}

module "iam" {
  source = "../../modules/iam"

  project_id            = var.project_id
  service_account_email = var.service_account_email

  roles = [
    "roles/datastore.owner",
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser",
  ]
}
