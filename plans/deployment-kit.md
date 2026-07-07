---
status: in-progress
depends: [import-module]
specs:
  - specs/deployment-kit.md
issues: []
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

- [ ] `docker build` succeeds for all three targets from a minimal example project
- [ ] Templates render correctly for a location key other than the origin projects' keys
- [ ] `examples/consolidated-starter/README.md` walk-through goes from clone to loaded Dagster UI using only kit + module
- [ ] No origin-project identifiers in `kit/`

## Risks / unknowns

- **Template mechanism choice** (envsubst vs. documented placeholders vs. tf
  `templatefile`) — pick the one the origin repos already prove out; don't invent.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
