# Module Interface

The contract consumers program against: deployment modes, the variable surface, and
outputs. Declarative — what must be true, not how resources implement it.

## Deployment modes

One `deployment_mode` variable selects the topology (`split`, `consolidated`,
`on-demand`). Shared infrastructure (Cloud
SQL, buckets, secrets, service accounts, run-worker Jobs) is identical across modes;
switching modes never touches it.

### `split` (default)

- Webserver: Service, scale 0→N, request-based billing (`cpu_idle = true`),
  `min_instance_count` configurable (default 0).
- Daemon: Worker Pool, exactly 1 instance.
- Code server: one internal gRPC Service per `code_locations` entry, scale 0→1,
  request-based billing.
- Any number of code locations.

### `consolidated`

- One always-on Service running three containers: webserver (ingress container,
  port 3000), code server (gRPC :3030, started first via container dependency +
  startup probe), daemon (no port).
- `max_instance_count = 1` — the daemon is a singleton; two instances would
  double-fire schedules.
- Instance-based billing (`cpu_idle = false`) on every container — under
  request-based billing the daemon sidecar is CPU-starved between UI requests and
  silently misses ticks.
- Startup probes must satisfy Cloud Run's constraint `timeout_seconds <= period_seconds`.
- Exactly one code location. More than one entry in `code_locations` fails at plan
  time via precondition ([modes are rungs, not forks](principles.md#modes-are-rungs-not-forks)).
- Webserver and daemon reach the code server at `localhost:3030`; no internal
  code-server Service and no invoker IAM for it exist in this mode.
- The Cloud SQL socket is provided by an explicit Cloud SQL Auth Proxy sidecar
  over a shared in-memory volume — Cloud Run's managed Cloud SQL volume does not
  function in multi-container services (empirically: the API silently keeps the
  mount on only one container and the socket never materializes), and the
  working v1 annotation path is not settable through the v2 API. Single-container
  split services keep the managed volume.

### `on-demand`

- The **same single-instance topology as `consolidated`** (same Service, same
  constraints: single code location enforced at plan time, instance-based billing,
  startup ordering, localhost gRPC) differing in exactly one thing:
  `min_instance_count = 0`. The instance scales to zero when idle and cold-starts
  on the next UI request.
- The daemon runs only while the instance is up (a UI session plus Cloud Run's
  ~15-minute idle window). Schedules and sensors do not fire unattended — the
  documented, accepted trade for demo and occasional-manual-run instances.
- `cpu_idle = false` is retained: Cloud Run scales down on absence of *requests*,
  not CPU, so while up the daemon has full CPU and reliably drains the run queue —
  even if the user closes the tab right after launching a run.
- Launched runs execute in their own Cloud Run Jobs and continue (writing status
  to Postgres) after the UI instance scales to zero.
- ~$0/month Cloud Run cost at idle; Cloud SQL remains the only always-on cost.

### Cost documentation

The README states each mode's always-on floor and the break-even points between
modes in dollars with assumptions
([cost transparency](principles.md#cost-transparency-over-cost-marketing)).
Consolidated-mode default sizing targets ~1 vCPU total (greenfield starter), not
parity with a loaded split deployment. On-demand shares that sizing; its floor is
the Cloud SQL instance alone.

## Ingress postures (webserver)

Exactly one of three, selectable in any deployment mode:

1. **IAP** — public ingress gated by Google-managed IAP for a Workspace domain;
   optional custom domain mapping.
2. **Public** — unauthenticated `allUsers` invoker. Only when explicitly enabled;
   never a default.
3. **Private + proxy** — internal ingress; access via `roles/run.invoker` granted to
   a consumer-side proxying service. Webserver supports a URL `path_prefix` so a
   reverse proxy can mount the UI under a subpath.

## Code locations

`code_locations` is a map keyed by location name. Each entry configures its code
server image/resources, its run-worker Job, and its service account. Per entry:

- **`secret_grants`** — Secret Manager secret IDs the location's service accounts
  (code server + run worker) may access.
- **`bucket_grants`** — GCS buckets with a role per bucket (read / read-write).
- **HMAC keys** — optionally issue per-service-account HMAC keys (for S3-compatible
  access, e.g. DuckDB httpfs), exposed as outputs/secrets.

No consumer-domain variables exist at the top level
([generic over project-named](principles.md#generic-over-project-named)).

## Workspace coupling rule

The module addresses each code server through an environment variable named
`CODE_SERVER_HOST_<UPPERCASED_LOCATION_KEY>` consumed by the `workspace.yaml` baked
into consumer images, with the gRPC port fixed at 3030. This coupling is part of the
contract: the kit templates (`specs/deployment-kit.md`) generate matching
`workspace.yaml` entries from the same location keys, and the module README states
the rule. A mismatch fails loudly in docs/examples rather than silently in gRPC.

## Database

The module targets a Cloud SQL Postgres instance the consumer provides
(`cloud_sql_connection_name`) and supports two database-provisioning modes:

- **Managed (default, `manage_database = true`)** — the module creates the
  database and a SQL user in the instance via the Admin API and generates the
  password.
- **External (`manage_database = false`)** — the database and user are
  provisioned outside the module (e.g. a multi-tenant shared instance whose
  root creates isolated tenant databases and SQL-native users; API-created
  users carry `cloudsqlsuperuser`, which would pierce tenant isolation). The
  consumer passes `db_password` (sensitive) and the module only composes the
  connection URL and its Secret Manager plumbing.

In both modes the module owns the `dagster-db-password` / `dagster-postgres-url`
secrets consumed by every component; the `database_name` output falls back to
`var.db_name` in external mode.

When the instance lives in a **different project** than the deployment (the
shared-instance pattern), `roles/cloudsql.client` on the *instance's* project is
required for the primary SA **and every per-location run-worker SA** — the module
grants it only in its own project and cannot reach across. Missing run-worker
grants fail late and opaquely: runs stick in STARTING while the worker Job dies
on "socket: No such file or directory" (the underlying 403 is only visible in
the job's proxy logs).

## Images

Image variables are ordinary, fully-managed inputs — no `lifecycle ignore_changes`
on image fields, because consumers deploy releases *through* Terraform with image
variables derived from the release tag
([Terraform is the image mover](principles.md#terraform-is-the-image-mover--never-ignore-image-changes)).
The README warns that any plan/apply must supply current image versions; stale local
pins would roll back deployed images.

## Outputs

- Webserver URL (whichever service carries ingress in the active mode)
- Cloud SQL instance connection name
- Per-location service account emails
- Per-location run-worker Job names (for `dagster.yaml` run-launcher config)
- HMAC key references where issued

## Principles

**Inherited** — from [principles.md](principles.md), these bite hardest here:

- [State addresses are the compatibility surface](principles.md#state-addresses-are-the-compatibility-surface)
  — mode gating uses `count`/`for_each` such that origin deployments adopt without churn.
- [Modes are rungs, not forks](principles.md#modes-are-rungs-not-forks) — one
  interface; mode-incompatible input fails fast at plan time.
- [Cost transparency over cost marketing](principles.md#cost-transparency-over-cost-marketing)
  — defaults size for the starter; break-evens documented.
