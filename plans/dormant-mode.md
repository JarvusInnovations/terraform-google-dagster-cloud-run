---
status: planned
depends: [import-module]
specs:
  - specs/module-interface.md
issues: []
---

# Plan: Add `dormant` deployment mode

## Scope

Third `deployment_mode` value in this repo's module: daemon Worker Pool at 0
instances, webserver and code servers `min = 0` request-based. The ~$0/month-idle
Cloud Run shape for demos and staging (proposed in a fleet cost review; a
demo-shaped origin deployment idling at ~$70/month is the motivating consumer).

Out of scope: automated wake-on-request orchestration (a future spec if wanted);
Cloud SQL stop/start scheduling.

## Implements

- [specs/module-interface.md](../specs/module-interface.md) — the `dormant` mode
  rules, including the documented no-schedules/no-sensors trade and persistence of
  shared state across dormancy.

## Approach

1. Extend the mode variable and gating locals; dormant reuses split's resources with
   scaling/billing overrides (daemon `manual_instance_count = 0`, `min = 0`,
   `cpu_idle = true` everywhere) rather than a third resource set — mode flips stay
   churn-free ([modes are rungs, not forks](../specs/principles.md#modes-are-rungs-not-forks)).
2. Document the wake procedure (flip mode, apply) and what does not run while
   dormant; state the residual Cloud SQL floor.
3. Validate by plan-diffing `dormant` vs `split` on an example: only scaling and
   billing fields may differ.

## Validation

- [ ] `tofu plan` diff between `split` and `dormant` on `examples/split-production` touches only instance-count / billing fields
- [ ] Flipping dormant → split → dormant produces symmetric plans (no ratchet)
- [ ] README documents the dormant floor (Cloud SQL only), the wake procedure, and the no-daemon trade
- [ ] Precondition/validation rejects nonsensical combinations (e.g. dormant + IAP domain-mapping expectations documented)

## Risks / unknowns

- **Worker Pool at 0 instances** — confirm the beta provider supports
  `manual_instance_count = 0` cleanly (vs. needing the pool absent); if not, dormant
  gates the daemon with `count` plus `moved` protection.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
