# Full split topology behind IAP — the production shape. Each component is its
# own Cloud Run resource: webserver Service (scales 0->N), daemon Worker Pool
# (singleton), a gRPC code-server Service per code location, run-worker Jobs.

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

data "google_project" "current" {
  project_id = var.project_id
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

    backup_configuration {
      enabled    = true
      start_time = "09:00"
    }
  }

  deletion_protection = true
}

module "dagster" {
  source = "../.." # registry consumers: JarvusInnovations/dagster-cloud-run/google

  project_id                = var.project_id
  region                    = var.region
  cloud_sql_connection_name = google_sql_database_instance.dagster.connection_name

  # split is the default; stated here for clarity
  deployment_mode = "split"

  webserver_image = var.webserver_image
  daemon_image    = var.daemon_image
  code_locations  = var.code_locations

  # IAP posture: public ingress gated by Google-managed IAP for a Workspace
  # domain, with an optional custom domain.
  iap_allowed_domain = var.iap_allowed_domain
  project_number     = data.google_project.current.number
  custom_domain      = var.custom_domain

  # Example of consumer-domain wiring: grant a data bucket and a config secret
  # to the pipeline without forking the module.
  extra_env = {
    DATA_BUCKET = var.data_bucket
  }

  bucket_grants = {
    data = {
      bucket          = var.data_bucket
      dagster_role    = "roles/storage.objectViewer"
      run_worker_role = "roles/storage.objectUser"
    }
  }
}

output "webserver_url" {
  value = module.dagster.webserver_url
}

output "webserver_iap_url" {
  value = module.dagster.webserver_iap_url
}

output "run_worker_job_names" {
  value = module.dagster.run_worker_job_names
}
