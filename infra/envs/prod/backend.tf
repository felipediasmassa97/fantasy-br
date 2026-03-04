terraform {
  backend "gcs" {
    bucket = "fantasy-br-tfstate-prod"
    prefix = "infra/prod"
  }
}
