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
  description = "Dagster webserver image (see kit/Containerfile webserver target)"
  type        = string
}

variable "daemon_image" {
  description = "Dagster daemon image (see kit/Containerfile daemon target)"
  type        = string
}

variable "iap_allowed_domain" {
  description = "Google Workspace domain for IAP-gated UI access; null keeps the webserver private"
  type        = string
  default     = null
}

variable "code_locations" {
  description = "Code locations — consolidated mode requires exactly one entry"
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
      run_worker_cpu    = "1"
      run_worker_memory = "2Gi"
    }
  }
}
