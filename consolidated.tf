# Single-instance Dagster deployment: webserver (ingress), daemon, and code server
# as three containers in ONE Cloud Run Service instance, for a single code location.
#
# Serves two deployment modes that share this identical topology and differ only in
# the scaling floor (see the scaling block below):
#   - "consolidated": min=1, always on. Lowest steady-state cost floor.
#   - "on-demand":    min=0, scales to zero when idle and cold-starts on the next UI
#                     visit. Best for demo / occasional-manual-run instances — pay
#                     only while someone is using it (plus the ~15 min Cloud Run
#                     idle window), $0 the rest of the time.
# When either mode is active, the split webserver Service, daemon Worker Pool, and
# code-server Service are not created.
#
# Key constraints (see README "Deployment modes"):
#   - max_instance_count = 1: the daemon must be a singleton. A second instance
#     would double-fire schedules and double-evaluate sensors.
#   - cpu_idle = false (instance-based billing) in BOTH modes: a request-billed
#     Service only gives sidecars CPU while the ingress is handling a request, which
#     starves the daemon between UI requests. Always-allocated CPU is required for
#     the daemon to tick reliably. This is orthogonal to min instances: on-demand
#     still scales to zero (Cloud Run scales down on absence of requests, not CPU),
#     and while the instance is up — including the idle window — the daemon has full
#     CPU. So on-demand's daemon drains the run queue / launches runs reliably during
#     the whole up-window, even if the user closes the tab right after launching.
#   - Inter-container traffic is over localhost. The code server listens on its
#     configured port (3030, matching the consumer's workspace.yaml); the webserver and
#     daemon reach it at CODE_SERVER_HOST_<LOC> = "localhost". No separate internal
#     code-server Service is created, and no gRPC traffic leaves the instance.
#   - Run workers are unaffected: they are still launched per-run as Cloud Run Jobs
#     by the CloudRunRunLauncher (see run_worker.tf). In on-demand mode this means a
#     run keeps executing in its own Job even after the UI instance scales to zero;
#     it writes status/logs to Postgres independently.

resource "google_cloud_run_v2_service" "consolidated" {
  count = local.uses_single_instance ? 1 : 0

  # Use beta provider for IAP support (parity with the split webserver)
  provider = google-beta

  name     = "dagster"
  location = var.region
  project  = var.project_id

  # Cloud Run IAP is GA (forcing BETA would show as a perpetual plan diff on
  # auto-promoted services — see webserver.tf).
  iap_enabled = var.iap_allowed_domain != null

  # Allow external access to the UI
  ingress = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  labels = local.common_labels

  template {
    service_account = google_service_account.dagster.email

    # max=1: the daemon must be unique (double-fire otherwise).
    # min: consolidated pins 1 (always on); on-demand sets 0 (scale to zero).
    scaling {
      min_instance_count = local.is_ondemand ? 0 : 1
      max_instance_count = 1
    }

    # Shared in-memory volume carrying the Cloud SQL Unix socket. Cloud Run's
    # managed cloud_sql_instance volume does NOT function in multi-container
    # services (the API silently keeps the mount on one container and the
    # socket never materializes — see specs/module-interface.md), so an
    # explicit Cloud SQL Auth Proxy sidecar below writes the socket here.
    volumes {
      name = "cloudsql"
      empty_dir {
        medium     = "MEMORY"
        size_limit = "32Mi"
      }
    }

    # --- Cloud SQL Auth Proxy (sidecar; started first, provides the socket) ---
    containers {
      name  = "cloudsql-proxy"
      image = var.cloud_sql_proxy_image

      args = [
        "--unix-socket", "/cloudsql",
        "--health-check",
        "--http-address", "0.0.0.0",
        "--http-port", "9801",
        "--structured-logs",
        var.cloud_sql_connection_name,
      ]

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = var.consolidated_proxy_resources.cpu
          memory = var.consolidated_proxy_resources.memory
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      # /startup returns 200 once the proxy is ready to serve connections.
      startup_probe {
        http_get {
          path = "/startup"
          port = 9801
        }
        initial_delay_seconds = 0
        timeout_seconds       = 5
        period_seconds        = 5
        failure_threshold     = 24
      }
    }

    # --- Code server (gRPC; starts after the proxy, before webserver/daemon) ---
    containers {
      name       = "code-server"
      image      = local.consolidated_location.image
      depends_on = ["cloudsql-proxy"]

      command = [
        "dagster", "api", "grpc",
        "--host", "0.0.0.0",
        "--port", tostring(local.consolidated_location.port),
        "--module-name", local.consolidated_location.module_name,
      ]

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = "DAGSTER_POSTGRES_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.postgres_url.secret_id
            version = "latest"
          }
        }
      }

      # Current image so Dagster tags runs / run workers with the right image
      env {
        name  = "DAGSTER_CURRENT_IMAGE"
        value = local.consolidated_location.image
      }

      resources {
        limits = {
          cpu    = var.consolidated_resources.code_server.cpu
          memory = var.consolidated_resources.code_server.memory
        }
        cpu_idle = false # instance-based billing (always-allocated CPU)
        # Boost bills only during startup; without it a fractional-CPU code server
        # importing heavy definitions can blow the 120s startup-probe budget and
        # wedge the whole instance (webserver/daemon depends_on this container).
        startup_cpu_boost = true
      }

      # gRPC startup probe - gates the webserver/daemon container start order.
      # Cloud Run requires timeout_seconds <= period_seconds (matches the split
      # code_server.tf probe); threshold 4 keeps the ~2 minute startup budget.
      startup_probe {
        grpc {
          port    = local.consolidated_location.port
          service = "DagsterApi"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 30
        period_seconds        = 30
        failure_threshold     = 4
      }
    }

    # --- Webserver (ingress container, HTTP 3000) ---
    containers {
      name       = "webserver"
      image      = var.webserver_image
      depends_on = ["cloudsql-proxy", "code-server"]

      # --path-prefix mirrors webserver.tf (reverse-proxy subpath support)
      command = concat(
        ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000"],
        var.path_prefix != "" ? ["--path-prefix", var.path_prefix] : []
      )

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      # Code server is co-located: reach it over localhost.
      # The consumer's workspace.yaml pins the port (3030), so only the host is supplied.
      env {
        name  = "CODE_SERVER_HOST_${upper(local.consolidated_location_key)}"
        value = "localhost"
      }

      env {
        name = "DAGSTER_POSTGRES_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.postgres_url.secret_id
            version = "latest"
          }
        }
      }

      ports {
        name           = "http1"
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.consolidated_resources.webserver.cpu
          memory = var.consolidated_resources.webserver.memory
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      startup_probe {
        http_get {
          path = "${var.path_prefix}/server_info"
          port = 3000
        }
        initial_delay_seconds = 5
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 12 # 2 minutes startup time
      }

      liveness_probe {
        http_get {
          path = "${var.path_prefix}/server_info"
          port = 3000
        }
        period_seconds    = 30
        timeout_seconds   = 5
        failure_threshold = 3
      }
    }

    # --- Daemon (sidecar; scheduler, sensors, run queue, run monitoring) ---
    containers {
      name       = "daemon"
      image      = var.daemon_image
      depends_on = ["cloudsql-proxy", "code-server"]

      command = ["dagster-daemon", "run"]

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      dynamic "env" {
        for_each = local.common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name  = "CODE_SERVER_HOST_${upper(local.consolidated_location_key)}"
        value = "localhost"
      }

      env {
        name = "DAGSTER_POSTGRES_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.postgres_url.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = var.consolidated_resources.daemon.cpu
          memory = var.consolidated_resources.daemon.memory
        }
        cpu_idle          = false # always-allocated so the daemon ticks without UI traffic
        startup_cpu_boost = true  # boost bills only during startup
      }

      # No liveness probe - dagster-daemon exposes no HTTP/TCP endpoint.
      # Cloud Run's automatic restart handles daemon crashes.
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.dagster_postgres_url
  ]

  lifecycle {
    # Consolidated mode co-locates exactly one code server. With more locations,
    # only the first would be wired in while run_worker.tf still creates Jobs for
    # all of them — fail fast instead of half-deploying.
    precondition {
      condition     = length(var.code_locations) == 1
      error_message = "deployment_mode = \"${var.deployment_mode}\" supports exactly one code location; var.code_locations has ${length(var.code_locations)} entries. Use deployment_mode = \"split\" for multiple code locations."
    }
  }
}
