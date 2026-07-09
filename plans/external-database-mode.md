---
status: in-progress
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

- [ ] `tofu validate` clean at root and in all examples
- [ ] Offline plan with `manage_database = false` + `db_password` set creates no `google_sql_database`/`google_sql_user` and no other delta vs managed mode
- [ ] Existing consumers unaffected by default (`manage_database = true` plans unchanged)
- [ ] v0.2.0 tagged and resolvable from the registry

## Risks / unknowns

- **Password-through-state** — external passwords flow through TF state into the
  module-owned secrets, same trust boundary as the generated ones; both live
  consumers already run this shape.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
