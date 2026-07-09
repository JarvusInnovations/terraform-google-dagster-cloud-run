# Create database in the provided Cloud SQL instance (skipped in external
# mode — the shared-instance root provisions the tenant database itself)
resource "google_sql_database" "dagster" {
  count = var.manage_database ? 1 : 0

  name     = var.db_name
  instance = local.cloud_sql_instance_name
  project  = var.project_id
}

# Create database user (skipped in external mode; API-created users join
# cloudsqlsuperuser, which would pierce shared-instance tenant isolation)
resource "google_sql_user" "dagster" {
  count = var.manage_database ? 1 : 0

  name     = var.db_user
  instance = local.cloud_sql_instance_name
  password = random_password.db_password.result
  project  = var.project_id

  deletion_policy = "ABANDON"
}

# Local to extract instance name from connection name
locals {
  # Connection name format: project:region:instance
  cloud_sql_instance_name = element(split(":", var.cloud_sql_connection_name), 2)
}
