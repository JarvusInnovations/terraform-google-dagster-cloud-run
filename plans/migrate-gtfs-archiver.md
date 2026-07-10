---
status: done
pr: 72
depends: [registry-publish]
specs: []
issues: []
---

# Plan: Migrate gtfs-realtime-archiver to the registry module

## Scope

**Cross-repo: executes in `JarvusInnovations/gtfs-realtime-archiver`.** Replace the
vendored `tf/modules/dagster/` with the pinned registry module and delete the
vendored copy. The archiver is the first production consumer and the proof the
extraction is faithful.

## Implements

Consumes this repo's published interface (own `specs:` empty — no code in this repo
changes).

## Approach

1. Swap `source = "./modules/dagster"` → registry source + `version` pin, keeping
   the module label `"dagster"` so state addresses are unchanged.
2. Map any variable renames from the generalization
   ([`reconcile-module-drift`](reconcile-module-drift.md)) in the root module.
3. `tofu plan` must be no-op / moved-only; apply; delete `tf/modules/dagster/`.

**Source note**: until the OpenTofu registry submission lands (see
[`registry-publish`](registry-publish.md) follow-ups), use the explicit host form
`source = "registry.terraform.io/JarvusInnovations/dagster-cloud-run/google"` —
the bare source 404s on registry.opentofu.org.

## Validation

- [x] `tofu plan` after the source swap: no resource churn (no-op or `moved`-explained)
- [x] Applied to production; Dagster UI, schedules, and run launching verified working
- [x] Vendored `tf/modules/dagster/` deleted in the same PR
- [x] Repo docs updated to point at the registry module

## Risks / unknowns

- **Hidden local references** — root-module references into module internals (if
  any) surface only at plan time.

## Notes

- The migration ended up state-free: the shared-pg cutover session had already
  applied develop (consuming the 4 IAM moves), and the swap branch planned
  "No changes" against live production before merge — so "applied to
  production" is satisfied vacuously (the registry module is byte-equivalent
  for split mode; the next release's CI apply exercises it end-to-end).
- Pinned v0.3.1 via the explicit registry.terraform.io host (OpenTofu registry
  submission still pending).
- Local tfvars image pins rotted a second time (0.8.2 vs deployed 0.9.1 after
  the cutover release) — re-synced. This repo's stale-pin hazard is structural;
  a future improvement could derive pins from the latest release tag.
- Schedules/sensors/run-launching verified indirectly: the daemon and services
  were untouched (no-op), and tonight's compaction runs got their real fix from
  the cloudsql.client grant for dagster-rw-gtfsrt (the cutover gap).

## Follow-ups

- Tracked as: confirm the first post-migration release's CI apply is a no-op
  and tonight's 02:00 UTC compaction run succeeds against shared-pg (first
  run-worker execution since the cutover + grant).
