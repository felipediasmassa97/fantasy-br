resource "google_firestore_database" "fantasy_br" {
  project     = var.gcp_project_id
  name        = "fantasy-br-${var.environment}-squads-teams"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # Free tier: 1 GiB storage, 50K reads/day, 20K writes/day
  # Used for: user_squads and user_teams collections
}
