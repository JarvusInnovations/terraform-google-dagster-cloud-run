# Minimal single-code-location Dagster on Cloud Run — the "consolidated" rung.
# Webserver + daemon + code server run as three containers in one always-on
# instance (~1 vCPU / 2.5Gi by default). Run workers launch per-run as Cloud
# Run Jobs. Lowest Dagster-native cost floor.
#
# Set deployment_mode = "on-demand" for the scale-to-zero variant (same
# topology, min=0): ~$0/mo Cloud Run when idle, cold start on the next UI
# visit, schedules/sensors only fire while awake.

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

# Smallest managed Postgres for Dagster's run/event storage.
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

  deployment_mode = var.deployment_mode

  webserver_image = var.webserver_image
  daemon_image    = var.daemon_image
  code_locations  = var.code_locations

  # Private by default: no IAP, no public invoker. Grant roles/run.invoker to
  # whoever should reach the UI, or set iap_allowed_domain for IAP, or flip
  # public_ingress = true (unauthenticated!) for a throwaway sandbox.
  iap_allowed_domain = var.iap_allowed_domain
  public_ingress     = false
}

output "webserver_url" {
  value = module.dagster.webserver_url
}

output "run_worker_job_names" {
  description = "Wire these into dagster.yaml's run-launcher job_name_by_code_location."
  value       = module.dagster.run_worker_job_names
}
