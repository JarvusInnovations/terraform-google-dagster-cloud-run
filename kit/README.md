# Deployment Kit

The non-Terraform half of a working deployment: a multi-target container
image build and Dagster instance/workspace configuration templates. The
Terraform module (`../`) provisions infrastructure; this kit is what actually
runs inside it. The module is consumable without the kit, but the kit is what
prevents adopters from stalling between "infrastructure exists" and "Dagster
runs".

## Contents

- [`Containerfile`](Containerfile) — builds three targets (`webserver`,
  `daemon`, `code-server`) from one build context via `uv sync` against your
  own `pyproject.toml`/`uv.lock`. Run workers reuse the `code-server` target;
  the module's `CloudRunRunLauncher` overrides its command per run. The same
  image set works in every deployment mode — mode is a Terraform concern,
  never baked into the image.
- [`dagster.yaml.tmpl`](dagster.yaml.tmpl) — Dagster instance config: Postgres
  storage over the Cloud SQL Unix socket, `CloudRunRunLauncher` wired to the
  module's run-worker Job names, GCS compute logs.
- [`workspace.yaml.tmpl`](workspace.yaml.tmpl) — one gRPC entry per code
  location.

## How this relates to the module: the workspace coupling rule

The module addresses each code server by an env var named
`CODE_SERVER_HOST_<UPPERCASED_LOCATION_KEY>`, gRPC port fixed at 3030 — see
[`specs/module-interface.md#workspace-coupling-rule`](../specs/module-interface.md#workspace-coupling-rule).
`workspace.yaml`'s `location_name` and `dagster.yaml`'s
`job_name_by_code_location` map key must both equal that same location key
(lowercase, matching your Terraform `code_locations` map key). That's what
lets the run launcher find the right run-worker Job and lets the
webserver/daemon reach the right code server. Get the key wrong in one file
and it fails loudly (a gRPC connection error, or "No run launcher defined for
code location") rather than silently misrouting — see the comments in both
templates for the exact rule.

## How the placeholders get resolved

Two kinds of placeholder live in these templates, resolved at two different
times — the same pattern the origin deployments already prove out (see
Provenance below), not an invented templating layer:

1. **Location keys** (`pipeline`, `CODE_SERVER_HOST_PIPELINE`,
   `dagster-run-worker-pipeline`) — literal text you replace by hand (or with
   a one-line `sed`/build script) for your real code location key(s) *before*
   the files are baked into your image. There's no template engine here on
   purpose: `envsubst` or Terraform's `templatefile` would be one more moving
   part to keep in sync with the module, for no benefit over a plain
   find-and-replace done once at setup.
2. **Runtime values** (the Postgres URL secret, `GCP_PROJECT_ID`,
   `GCP_REGION`, `DAGSTER_LOGS_BUCKET`) — Dagster's own `env:` config
   indirection, left untouched in the templates. These resolve from process
   environment variables the Terraform module sets on each container at
   deploy time (`main.tf`'s `common_env`, plus the `DAGSTER_POSTGRES_URL`
   secret mount) — never baked into the image, so the same image runs
   unmodified across projects/regions.

Practical flow: copy `dagster.yaml.tmpl` and `workspace.yaml.tmpl` into your
own repo as `deploy/dagster.yaml` and `deploy/workspace.yaml` (the paths
`kit/Containerfile` expects), replace the `pipeline` placeholder with your
real location key(s), add a block per additional code location, then build
with `kit/Containerfile`. See
[`examples/consolidated-starter`](../examples/consolidated-starter/README.md)
for the full clone-to-loaded-UI walk-through.

## Image tagging

Tagging and pushing images is your CI's job, not this kit's — the kit only
builds. Deploys flow through `tofu apply` with release-derived image
variables; see the root README's
["Images move with your deploys"](../README.md#images-move-with-your-deploys--dont-apply-with-stale-pins)
section for why the module has no `lifecycle ignore_changes` on image fields
and what that implies for your apply process.

## Validation posture

These templates are exercised by the examples: each example's README walks
from `docker build` through `tofu apply` to a loaded Dagster UI. A kit change
that breaks that walk-through is a bug even if the module still validates.

## Provenance

Generalized from the Dagster container build and instance/workspace config
running in production behind
[gtfs-realtime-archiver](https://github.com/JarvusInnovations/gtfs-realtime-archiver)
(`Containerfile.dagster`, `deploy/dagster.yaml`, `deploy/workspace.yaml`),
stripped of everything project-specific (the tippecanoe build, dbt manifest
baking, and other consumer-domain packages/paths).
