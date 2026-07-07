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

variable "proxy_service_account_email" {
  description = "Service account of the proxying service; granted run.invoker on the private webserver"
  type        = string
}

variable "code_locations" {
  description = "Code locations"
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
