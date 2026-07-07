# Deployment Kit

The non-Terraform half of a working deployment: container image build and Dagster
instance/workspace configuration. Lives in `kit/` and is referenced by the examples.
The Terraform module is consumable without the kit, but the kit is what prevents
adopters from stalling between "infrastructure exists" and "Dagster runs".

## Container image

A multi-target `Containerfile` template producing, from one build context:

- `webserver` — runs `dagster-webserver`
- `daemon` — runs `dagster-daemon run`
- `code-server` — runs `dagster api grpc` on port 3030
- run-worker execution uses the code-server target (the run launcher overrides the
  command)

Requirements:

- Dependencies installed with `uv` from the consumer's `pyproject.toml`/`uv.lock`.
- The same image set works in every deployment mode — mode is a Terraform concern,
  never baked into the image.
- Image tagging/pushing is the consumer's CI's job
  ([images move out-of-band](principles.md#images-move-out-of-band)).

## `dagster.yaml` template

Instance config template with env-placeholder wiring for:

- Postgres storage via the Cloud SQL Unix socket
- `dagster_contrib_gcp.cloud_run.run_launcher.CloudRunRunLauncher` with
  `job_name_by_code_location` populated from the module's run-worker Job name
  outputs
- GCS compute-log manager

## `workspace.yaml` template

One gRPC entry per code location, generated from the same location keys the module
uses: host `${CODE_SERVER_HOST_<UPPERCASED_KEY>}`, port 3030. This is the consumer
side of the [workspace coupling rule](module-interface.md#workspace-coupling-rule) —
the kit and the module derive from one key so they cannot drift apart silently.

## Validation posture

Kit templates are exercised by the examples: each example's README walks from
`docker build` through `tofu apply` to a loaded Dagster UI. A kit change that breaks
that walk-through is a bug even if the module still validates.
