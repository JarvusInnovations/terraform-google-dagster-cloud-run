# Negative-test fixture: consolidated mode must reject >1 code location at
# plan time. CI runs `tofu plan -var-file=two-locations.tfvars` and expects
# the precondition error. Not a working configuration.
project_id      = "example-project"
webserver_image = "us-docker.pkg.dev/EXAMPLE/EXAMPLE/dagster-webserver:latest"
daemon_image    = "us-docker.pkg.dev/EXAMPLE/EXAMPLE/dagster-daemon:latest"

code_locations = {
  alpha = {
    image             = "us-docker.pkg.dev/EXAMPLE/EXAMPLE/dagster-code-server:latest"
    module_name       = "alpha.definitions"
    port              = 3030
    run_worker_cpu    = "1"
    run_worker_memory = "2Gi"
  }
  beta = {
    image             = "us-docker.pkg.dev/EXAMPLE/EXAMPLE/dagster-code-server:latest"
    module_name       = "beta.definitions"
    port              = 3030
    run_worker_cpu    = "1"
    run_worker_memory = "2Gi"
  }
}
