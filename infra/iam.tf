locals {
  sa_member = "serviceAccount:${var.app_service_account_email}"
}

# Firestore read/write — required for squad and team persistence
resource "google_project_iam_member" "firestore_user" {
  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = local.sa_member
}

# BigQuery SELECT — required for all app read queries against dbt mart tables
resource "google_project_iam_member" "bigquery_data_viewer" {
  project = var.gcp_project_id
  role    = "roles/bigquery.dataViewer"
  member  = local.sa_member
}

# BigQuery job execution — required to run queries (even read-only ones)
resource "google_project_iam_member" "bigquery_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = local.sa_member
}
