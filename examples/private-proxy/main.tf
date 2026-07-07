# Private webserver behind a reverse proxy — no public invoker, no IAP. An
# existing app (e.g. another Cloud Run service) forwards /dagster/* to the
# webserver, minting Google ID tokens so the hop authenticates at the IAM
# layer. The module serves the UI under path_prefix so generated URLs match
# what the proxy forwards.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

resource "google_sql_database_instance" "dagster" {
  name             = "dagster"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = 10
  }

  deletion_protection = true
}

module "dagster" {
  source = "../.." # registry consumers: JarvusInnovations/dagster-cloud-run/google

  project_id                = var.project_id
  region                    = var.region
  cloud_sql_connection_name = google_sql_database_instance.dagster.connection_name

  webserver_image = var.webserver_image
  daemon_image    = var.daemon_image
  code_locations  = var.code_locations

  # Private + proxy posture
  iap_allowed_domain = null
  public_ingress     = false
  path_prefix        = "/dagster"

  # Keep the UI warm so the proxy hop doesn't eat a cold start.
  webserver_min_instances = 1
}

# The proxying service's SA gets run.invoker on the private webserver — this is
# the one binding the module deliberately leaves to the consumer.
resource "google_cloud_run_v2_service_iam_member" "proxy_invokes_webserver" {
  project  = var.project_id
  location = var.region
  name     = module.dagster.webserver_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.proxy_service_account_email}"
}

output "webserver_url" {
  description = "Internal Cloud Run URL — only callable by principals holding run.invoker"
  value       = module.dagster.webserver_url
}
