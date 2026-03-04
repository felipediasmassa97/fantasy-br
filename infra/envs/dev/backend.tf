terraform {
  backend "gcs" {
    bucket = "fantasy-br-tfstate-dev"
    prefix = "infra/dev"
  }
}
