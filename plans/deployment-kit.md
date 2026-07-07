---
status: done
depends: [import-module]
specs:
  - specs/deployment-kit.md
issues: []
pr: 2
---

# Plan: Deployment kit (Containerfile + Dagster config templates)

## Scope

Ship `kit/`: the multi-target Containerfile template and the `dagster.yaml` /
`workspace.yaml` templates, generalized from the archiver's working versions
(`Containerfile.dagster`, `deploy/*.yaml`) — strip gtfsrt-specific packages
(tippecanoe build, dbt bake) down to a clean uv-based Dagster skeleton. Wire the
examples' READMEs to walk build → apply → loaded UI.

## Implements

- [specs/deployment-kit.md](../specs/deployment-kit.md) — all sections
- [specs/module-interface.md](../specs/module-interface.md) — the workspace
  coupling rule, from the consumer side

## Approach

1. `kit/Containerfile` with `webserver` / `daemon` / `code-server` targets;
   dependencies via `uv sync` against the consumer's lockfile.
2. `kit/dagster.yaml.tmpl` — Postgres via Cloud SQL socket, `CloudRunRunLauncher`
   with `job_name_by_code_location` sourced from module outputs, GCS compute logs.
3. `kit/workspace.yaml.tmpl` — per-location gRPC entries using
   `CODE_SERVER_HOST_<KEY>`:3030, with the key-derivation rule documented inline.
4. Exercise with a non-`gtfsrt` location key to prove nothing is name-coupled.

## Validation

- [x] `docker build` succeeds for all three targets from a minimal example project
- [x] Templates render correctly for a location key other than the origin projects' keys
- [ ] `examples/consolidated-starter/README.md` walk-through goes from clone to loaded Dagster UI using only kit + module
- [x] No origin-project identifiers in `kit/`

## Risks / unknowns

- **Template mechanism choice** (envsubst vs. documented placeholders vs. tf
  `templatefile`) — pick the one the origin repos already prove out; don't invent.

## Notes

- **Template mechanism**: no engine at all, by design — the origin repo's own
  pattern is plain YAML with two placeholder kinds resolved at two different
  times: (1) location keys (`pipeline`, `CODE_SERVER_HOST_PIPELINE`,
  `dagster-run-worker-pipeline`) replaced by hand/`sed` once at setup, and (2)
  Dagster's native `env:` config indirection for runtime values (secrets,
  project ID, bucket name), resolved from process env at container start.
  `envsubst`/`templatefile` would add a moving part with no benefit over
  find-and-replace done once.
- **Correctness fix over the origin**: the origin's `dagster.yaml` keyed
  `job_name_by_code_location` on the Dagster module name
  (`dagster_pipeline.definitions`) while its `workspace.yaml` set
  `location_name: gtfsrt` — those don't match, and `CloudRunRunLauncher`
  looks runs up by `location_name`, not module name (confirmed by reading
  `dagster_contrib_gcp/cloud_run/run_launcher.py`). The kit templates key
  `job_name_by_code_location` on the same `location_name`/Terraform-map-key
  used everywhere else, closing that latent mismatch rather than propagating
  it.
- **Containerfile generalization beyond origin**: the code-server target's
  `--module-name` is a `--build-arg` (`DAGSTER_MODULE_NAME`) rather than
  hard-coded in the Dockerfile, so a consumer parameterizes per-location
  builds without editing the file at all.
- Docker build validation used a throwaway `dagster`/`dagster-webserver`/
  `dagster-gcp` project (no `dagster-contrib-gcp` install needed — it's only
  imported by the Dagster process at runtime via `dagster.yaml`'s
  `run_launcher.module`, never at image-build time).

## Follow-ups

- Tracked as: the full `consolidated-starter` walk-through (build → push →
  `tofu apply` → loaded UI) has not been exercised end-to-end against a real
  GCP project — only the docker-build and template-rendering steps were
  verifiable without one. Needs a maintainer with sandbox-project access to
  run it once against a real deploy per
  [principles: production deployments are the test bed](../specs/principles.md#production-deployments-are-the-test-bed).
