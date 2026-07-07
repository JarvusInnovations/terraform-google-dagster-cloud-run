variable "project_id" {
  description = "GCP project to deploy into"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "webserver_image" {
  description = "Dagster webserver image"
  type        = string
}

variable "daemon_image" {
  description = "Dagster daemon image"
  type        = string
}

variable "iap_allowed_domain" {
  description = "Google Workspace domain allowed through IAP (e.g. \"example.com\")"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for the webserver (requires a DNS record); null to use the run.app URL"
  type        = string
  default     = null
}

variable "data_bucket" {
  description = "Example consumer data bucket granted to the pipeline"
  type        = string
  default     = "example-data-bucket"
}

variable "code_locations" {
  description = "Code locations; split mode supports any number"
  type = map(object({
    image             = string
    module_name       = string
    port              = number
    run_worker_cpu    = string
    run_worker_memory = string
  }))
  default = {
    pipeline = {
      image             = "us-docker.pkg.dev/EXAMPLE/EXAMPLE/dagster-code-server:latest"
      module_name       = "my_pipeline.definitions"
      port              = 3030
      run_worker_cpu    = "2"
      run_worker_memory = "4Gi"
    }
  }
}
