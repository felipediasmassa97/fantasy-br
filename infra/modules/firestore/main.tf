resource "google_firestore_database" "this" {
  project     = var.project_id
  name        = var.database_name
  location_id = var.location_id
  type        = var.type
}
