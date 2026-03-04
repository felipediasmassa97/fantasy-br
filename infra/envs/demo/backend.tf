terraform {
  backend "gcs" {
    bucket = "fantasy-br-tfstate-demo"
    prefix = "infra/demo"
  }
}
