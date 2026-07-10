---
status: done
pr: 4
depends: [registry-publish]
specs:
  - specs/module-interface.md
issues: []
---

# Plan: External-database mode (v0.2.0)

## Scope

Port the `manage_database = false` / `db_password` external-database mode that
both origin deployments added to their vendored copies on 2026-07-09 when they
moved Dagster metadata onto a multi-tenant shared Cloud SQL instance. Release
as v0.2.0 — both migration PRs are blocked on it (the vendored copies are now
ahead of v0.1.0).

## Implements

- [specs/module-interface.md](../specs/module-interface.md) — the Database
  section (amended 2026-07-09).

## Approach

Port the consumers' identical diffs (taking the better-commented variant):
count-gate `google_sql_database` / `google_sql_user` on `manage_database`,
`effective_db_password` local feeding both module-owned secrets, `database_name`
output falls back to `var.db_name`, new `manage_database` + sensitive
`db_password` variables. README database note. Tag v0.2.0 after merge.

## Validation

- [x] `tofu validate` clean at root and in all examples
- [x] Offline plan with `manage_database = false` + `db_password` set creates no `google_sql_database`/`google_sql_user` and no other delta vs managed mode
- [x] Existing consumers unaffected by default (`manage_database = true` plans unchanged)
- [x] v0.2.0 tagged and resolvable from the registry

## Risks / unknowns

- **Password-through-state** — external passwords flow through TF state into the
  module-owned secrets, same trust boundary as the generated ones; both live
  consumers already run this shape.

## Notes

- v0.2.0 was immediately followed the same day by v0.2.1/v0.3.0/v0.3.1 (sizing
  coupling, Auth Proxy sidecar, reserved volume name) from the first production
  apply — see the migrate-second-consumer closeout for the full account.
- Cross-project grant requirement (cloudsql.client on the instance's project for
  primary + run-worker SAs) documented in README/spec after it bit in production.

## Follow-ups

None.
