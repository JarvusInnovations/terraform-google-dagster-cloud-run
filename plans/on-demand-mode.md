---
status: done
pr: 3
depends: [import-module]
specs:
  - specs/module-interface.md
issues: []
---

# Plan: Add `on-demand` deployment mode (port of archiver PR #70)

## Scope

Third `deployment_mode` value: the consolidated single-instance topology with
`min_instance_count = 0` — scales to zero when idle, cold-starts on the next UI
visit, ~$0/month Cloud Run at idle. Designed for the demo-shaped origin
deployment (fleet cost review: ~$70/month idle today) and any staging stack.

The implementation is a port of gtfs-realtime-archiver PR #70, which was
authored against the consumer repo but belongs here — it will be closed
unmerged there in favor of this port (maintainer decision 2026-07-07). This
plan supersedes the earlier `dormant` design: on-demand achieves the same idle
floor with a strictly better wake story (a request, not a `tofu apply`).

Out of scope: in-process code loading to shrink cold starts (possible
follow-up); Cloud SQL stop/start scheduling.

## Implements

- [specs/module-interface.md](../specs/module-interface.md) — the `on-demand`
  mode rules (amended 2026-07-07 replacing `dormant`).

## Approach

1. Port PR #70's semantic diff onto the imported module: `is_ondemand` +
   `uses_single_instance` locals (single-instance resource, ingress-carrier
   locals, and the precondition all key off `uses_single_instance`),
   `deployment_mode` validation extended to `on-demand`,
   `min_instance_count = is_ondemand ? 0 : 1`, and the consolidated.tf header
   rewritten for both modes (including the "scales down on absence of requests,
   not CPU" rationale and the runs-outlive-the-instance note).
2. README: replace the *(planned)* row with the real mode + trade-offs
   (schedules/sensors only fire while awake; cold start per session).
3. CI: extend the offline plan checks — on-demand plan succeeds, and the
   two-location precondition also rejects in on-demand mode.

## Validation

- [x] Offline plan of `consolidated-starter` with `deployment_mode = "on-demand"` succeeds and differs from consolidated only in `min_instance_count`
- [x] Two-location fixture fails the precondition in on-demand mode too
- [x] `tofu validate` passes at root and in all examples
- [x] README documents the mode, its trade-offs, and its ~$0 idle floor
- [x] Upstream PR #70 closed with a pointer to the port

## Risks / unknowns

- **Cold-start UX** — three containers gated by the code-server gRPC probe;
  fine for demos, must be documented so nobody puts scheduled workloads on it.

## Notes

- Verified the plan-diff criterion precisely: consolidated vs on-demand offline
  plans differ in exactly one line (`min_instance_count = 1` vs `0`).
- Port delta: the single-location precondition error message now interpolates
  `var.deployment_mode` — the hardcoded "consolidated" wording was misleading
  when the precondition fired in on-demand mode.
- Upstream PR #70 closed unmerged with a pointer to this port; the archiver
  never carries the mode directly and picks it up at migration.

## Follow-ups

- Tracked as: in-process code loading (no separate code-server container) as a
  cold-start optimization for on-demand — noted as a possible future spec, not
  planned.
