locals {
  database_names = {
    dev  = "fdmdev"
    demo = "fdmdemo"
    prod = "fdmprod"
  }

  database_name = local.database_names[var.environment]
  schema_name   = "fantasy_br"

  # BigQuery dataset ID (combines database and schema concept)
  # Note: BigQuery dataset IDs cannot contain hyphens, so we use underscores
  dataset_id = replace("${local.database_name}_${local.schema_name}", "-", "_")
}
