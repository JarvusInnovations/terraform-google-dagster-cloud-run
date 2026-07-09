# terraform-google-dagster-cloud-run

Deploy open-source [Dagster](https://dagster.io) on Google Cloud Run — fully
serverless, no GKE cluster, no VMs.

> **Status: pre-release.** Extracted from two production deployments; not yet
> published to the Terraform Registry. Interfaces may change until `v1.0.0`.

## What it deploys

| Component | Cloud Run shape |
| --- | --- |
| Dagster webserver (UI) | Service (IAP-gated, public, or private + proxy) |
| Dagster daemon | Worker Pool (singleton) |
| Code server(s) | Service per code location (internal gRPC, port 3030) |
| Run workers | Job per code location, launched per-run by [`dagster-contrib-gcp`](https://github.com/dagster-io/community-integrations/tree/main/libraries/dagster-contrib-gcp)'s `CloudRunRunLauncher` |
| Run/event storage | Cloud SQL Postgres. The *instance* is always yours to provide (`cloud_sql_connection_name`); **by default the module provisions the database + user inside it**. Set `manage_database = false` + `db_password` when the database + user are provisioned externally too (e.g. a multi-tenant shared instance) |

The module also creates per-code-location service accounts with least-privilege
IAM, Secret Manager plumbing for the Postgres URL, a compute-logs bucket, and
(optionally) per-run-worker GCS HMAC keys for DuckDB/dbt-duckdb `gs://` writes.

## Usage

```hcl
module "dagster" {
  # Until the registry release, pin a git ref:
  # source = "github.com/JarvusInnovations/terraform-google-dagster-cloud-run?ref=<tag>"
  source = "JarvusInnovations/dagster-cloud-run/google"

  project_id                = var.project_id
  region                    = "us-central1"
  cloud_sql_connection_name = google_sql_database_instance.dagster.connection_name

  deployment_mode = "consolidated" # or "split"

  webserver_image = "…/dagster-webserver:1.2.3"
  daemon_image    = "…/dagster-daemon:1.2.3"

  code_locations = {
    pipeline = {
      image             = "…/dagster-code-server:1.2.3"
      module_name       = "my_pipeline.definitions"
      port              = 3030
      run_worker_cpu    = "1"
      run_worker_memory = "2Gi"
    }
  }

  iap_allowed_domain = "example.com" # or null — see "Ingress postures"
}
```

Start from [`examples/`](examples/): `consolidated-starter` (minimal, cheapest),
`split-production` (IAP, multi-location-ready), `private-proxy` (UI behind your
own reverse proxy).

## Deployment modes

One `deployment_mode` toggle moves a deployment between topologies; the
database, buckets, secrets, service accounts, and run workers are identical
across modes.

| Mode | Shape | Always-on floor* |
| --- | --- | --- |
| `split` (default) | Webserver Service (0→N) + daemon Worker Pool + code-server Service per location | ~$100/mo in practice: the always-on daemon (~$64) keeps the "scale-to-zero" code server permanently warm (~30s gRPC polls) |
| `consolidated` | Webserver + daemon + code server as three containers in **one** always-on Service; single code location only (enforced at plan time) | ~$55/mo at the default 1 vCPU / 2.5Gi sizing |
| `on-demand` | Same single-instance topology as `consolidated`, but `min = 0` — scales to zero when idle, cold-starts on the next UI visit; schedules/sensors only fire while awake | ~$0/mo Cloud Run at idle; Cloud SQL remains |

\* us-central1, instance-based billing, no committed-use discount. **Break-even:
consolidated only saves money at roughly ≤1.5 vCPU total.** Sized up to
2 vCPU / 2.5Gi it costs about the same as a loaded split deployment — at that
point it's a topology simplification, not a cost cut.

Consolidated-mode constraints (enforced/encoded by the module):
`max_instance_count = 1` (the daemon must be a singleton — note a revision
rollout can still briefly overlap old/new instances), instance-based billing on
every container (request-based billing starves the daemon sidecar between UI
requests), startup ordering via container dependencies + a gRPC startup probe,
and the code server reached over `localhost:3030`.

## Ingress postures

1. **IAP** — set `iap_allowed_domain` (+ optional `custom_domain`,
   `project_number`): public ingress gated by Google-managed IAP.
2. **Public** — `iap_allowed_domain = null`, `public_ingress = true`: an
   `allUsers` invoker binding. Unauthenticated; never make this the default
   posture for anything real.
3. **Private + proxy** — `iap_allowed_domain = null`, `public_ingress = false`:
   no invoker binding is created; grant `roles/run.invoker` to your proxying
   service's SA and set `path_prefix` (e.g. `"/dagster"`) so UI-generated URLs
   match the forwarded subpath.

## Consumer wiring (no forks)

The module has no project-specific variables. Express your pipeline's needs
through generic maps:

- `extra_env` — plain env vars injected into every component.
- `bucket_grants` — per-bucket IAM roles for the primary SA and/or run-worker SAs.
- `secret_grants` — Secret Manager accessor grants.
- `run_worker_secret_env` — env vars injected into run workers as secret
  references (kept off code servers deliberately: they introspect the asset
  graph and shouldn't hold materialization credentials).
- `enable_dbt_hmac_keys` + `hmac_env_names` — per-run-worker GCS HMAC keys for
  dbt-duckdb httpfs `gs://` writes.

## Workspace coupling rule

The module addresses each code server through an env var named
`CODE_SERVER_HOST_<UPPERCASED_LOCATION_KEY>`, and the gRPC port is fixed at
3030. The `workspace.yaml` baked into your images must use the same key
(`host: ${CODE_SERVER_HOST_<KEY>}`, `port: 3030`) — templates land in `kit/`.

## Images move with your deploys — don't apply with stale pins

Image variables are ordinary managed inputs: the proven pattern is a release CI
job that runs `tofu apply` with image values derived from the release tag. The
module deliberately has **no** `lifecycle ignore_changes` on images (it would
silently break Terraform-mediated deploys). The corollary: an apply with stale
image variables **rolls your deployment back** — always pass current image
versions, or keep tfvars pins in sync with your latest release.

## Provider requirements

`google` and `google-beta` ≥ 7.0 (several resources — IAP, Worker Pools, the
consolidated multi-container Service — use `google-beta`), OpenTofu/Terraform
≥ 1.6.

## Support scope

The [`examples/`](examples/) are the contract: configurations materially
matching an example are supported; bespoke topologies are yours to operate.
Issues and PRs welcome.

## Origin

Extracted from the Dagster deployments behind
[gtfs-realtime-archiver](https://github.com/JarvusInnovations/gtfs-realtime-archiver)
(gtfsrt.io) and a second production data platform, where this module runs in
production. Built and maintained by [Jarvus Innovations](https://jarv.us).

## License

[Apache-2.0](LICENSE)
