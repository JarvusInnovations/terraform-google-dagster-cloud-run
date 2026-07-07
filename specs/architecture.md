# Architecture

## What this is

A Terraform module that deploys open-source Dagster on Google Cloud Run — fully
serverless: no GKE cluster, no VMs. It is the extraction of a module that ran (as
vendored copies) inside two production repos:

- `JarvusInnovations/gtfs-realtime-archiver` — `tf/modules/dagster/` (origin; adds
  consolidated mode via PR #67)
- a second production data platform (private repo) — vendored copy that added
  private-ingress + reverse-proxy mode, `--path-prefix`, and per-SA HMAC keys

The published module is the superset of both, with consumer-specific naming
generalized (see [principles: generic over project-named](principles.md#generic-over-project-named)).

## Components deployed

| Component | Cloud Run shape | Notes |
| --- | --- | --- |
| Dagster webserver | Service | ingress posture per `module-interface.md` |
| Dagster daemon | Worker Pool | singleton; always-allocated CPU by design |
| Code server(s) | Service per code location | internal gRPC, port 3030 |
| Run workers | Job per code location | launched per-run by `dagster-contrib-gcp`'s `CloudRunRunLauncher` |
| Run/event storage | Cloud SQL Postgres | Unix-socket mount `/cloudsql/...` |
| Secrets | Secret Manager | instance config + per-location grants |

In `consolidated` mode the webserver, daemon, and single code server collapse into
one multi-container Service (see `module-interface.md`).

## Repo structure

Terraform Registry standard module layout:

```
main.tf, variables.tf, outputs.tf, versions.tf, ...   # module at repo root
examples/
├── consolidated-starter/    # minimal single-location starter (the cost-floor rung)
├── split-production/        # full split topology, IAP ingress
└── private-proxy/           # split, private ingress behind a proxying service
kit/                         # deployment kit — see specs/deployment-kit.md
specs/  plans/               # specops
```

## Provider posture

- Cloud Run Worker Pools and multi-container features require `google-beta`; the
  module pins provider version ranges and documents the beta dependency in README.
- Provider version bumps are validated by CI plans of every example before release
  (see [principles: production deployments are the test bed](principles.md#production-deployments-are-the-test-bed)).

## CI

Every PR runs: `tofu fmt -check -recursive`, `tofu validate` at root and in each
example, and `tofu plan` of each example against a sandbox project when credentials
are available. A release is a semver tag on `main`.

## Versioning & distribution

- Published to the Terraform Registry as `JarvusInnovations/dagster-cloud-run/google`.
- Semver. Pre-`v1.0.0`, minor versions may change variable names (never state
  addresses — see [principles](principles.md#state-addresses-are-the-compatibility-surface)).
- Consumers pin a version; the two origin repos consume the registry module and
  delete their vendored copies.

## Non-goals

- Kubernetes/GKE deployment (Dagster's Helm chart owns that)
- Dagster+ / Dagster Cloud hybrid agents
- Managing the contents of Dagster images (the kit provides templates; consumers own
  their images and CI)
