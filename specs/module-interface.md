# Module Interface

The contract consumers program against: deployment modes, the variable surface, and
outputs. Declarative — what must be true, not how resources implement it.

## Deployment modes

One `deployment_mode` variable selects the topology. Shared infrastructure (Cloud
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

### `dormant`

- Every Cloud Run resource scaled to zero: daemon Worker Pool at 0 instances,
  webserver and code servers `min = 0` with request-based billing.
- No schedules, sensors, or run-queue draining execute while dormant — this is the
  documented, accepted trade (demo/staging shape).
- Waking is a mode flip to `split` or `consolidated`; state (Cloud SQL, buckets,
  secrets) persists across dormancy. Cloud SQL remains the only always-on cost.

### Cost documentation

The README states each mode's always-on floor and the break-even points between
modes in dollars with assumptions
([cost transparency](principles.md#cost-transparency-over-cost-marketing)).
Consolidated-mode default sizing targets ~1 vCPU total (greenfield starter), not
parity with a loaded split deployment.

## Ingress postures (webserver)

Exactly one of three, selectable in any non-dormant mode:

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
