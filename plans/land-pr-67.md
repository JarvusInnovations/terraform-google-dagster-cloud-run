---
status: in-progress
depends: []
specs: []
issues: []
---

# Plan: Land consolidated mode (gtfs-realtime-archiver PR #67)

## Scope

**Cross-repo: executes in `JarvusInnovations/gtfs-realtime-archiver`** (branch
`claude/dagster-container-cost-exploration-u6u1fp`, PR #67). Fix the outstanding
code-review and cost-review findings recorded on the PR, then merge. This makes the
archiver's vendored module the reference implementation of `consolidated` mode
before extraction begins.

Out of scope: `dormant` mode ([`dormant-mode`](dormant-mode.md)), merging the
second origin deployment's drift ([`reconcile-module-drift`](reconcile-module-drift.md)).

## Implements

The `consolidated` rules of [specs/module-interface.md](../specs/module-interface.md),
implemented upstream; conformance lands in this repo via
[`import-module`](import-module.md) (hence empty `specs:` — the drift auditor can't
hold this repo's tree to it yet).

## Approach

1. Fix code-server startup probe: `timeout_seconds = 30 / period_seconds = 10`
   violates Cloud Run's `timeout <= period`; match split mode's `30/30`.
2. Add `lifecycle` precondition: consolidated mode requires
   `length(var.code_locations) == 1`.
3. Fix doc cross-references: `consolidated.tf` cites a DESIGN.md section that lives
   in CLAUDE.md; README lacks `dagster_deployment_mode`.
4. Resolve image-pin drift before any apply: a 2026-07-07 `tofu plan` wanted to
   downgrade five Cloud Run resources (daemon 0.8.2 → 0.4.13). *(Amended after
   investigation:)* the drift source is a stale local tfvars, not out-of-band image
   movement — the release CI deploys **via `tofu apply` with release-derived image
   vars**, so `lifecycle ignore_changes` would break CI deploys and must not be
   added (see the amended principle
   [Terraform is the image mover](../specs/principles.md#terraform-is-the-image-mover--never-ignore-image-changes)).
   Fix: reconcile the local tfvars pins to the current release and document the
   stale-pin hazard in the repo docs.
5. Right-size `consolidated_resources` defaults toward ~1 vCPU total and document
   the split↔consolidated break-even (per the PR's cost-review comment: 2 vCPU/2.5Gi
   defaults ≈ $105–110/mo is a wash against the measured split floor ≈ $100/mo).
6. `tofu validate` + full `tofu plan` against the live stack; merge per repo flow.

## Validation

- [ ] Consolidated code-server startup probe satisfies `timeout_seconds <= period_seconds`
- [ ] `tofu plan` with two `code_locations` entries in consolidated mode fails with the precondition message
- [ ] All doc cross-references in the diff resolve; README documents `dagster_deployment_mode`
- [ ] Full `tofu plan` against the live archiver stack shows no image downgrades
- [ ] Break-even documented alongside the resized defaults
- [ ] PR #67 merged with checks green

## Risks / unknowns

- **Fractional sidecar CPU** — 250m/500m splits summing to 1 vCPU may be rejected by
  Cloud Run; fallback is whole-CPU containers at a higher floor (watch the plan/apply).
- **`ignore_changes` on images changes day-2 semantics** — confirm CI (not Terraform)
  is the sole image mover in the archiver repo before adopting.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
