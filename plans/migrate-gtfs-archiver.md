---
status: planned
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

## Validation

- [ ] `tofu plan` after the source swap: no resource churn (no-op or `moved`-explained)
- [ ] Applied to production; Dagster UI, schedules, and run launching verified working
- [ ] Vendored `tf/modules/dagster/` deleted in the same PR
- [ ] Repo docs updated to point at the registry module

## Risks / unknowns

- **Hidden local references** — root-module references into module internals (if
  any) surface only at plan time.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
