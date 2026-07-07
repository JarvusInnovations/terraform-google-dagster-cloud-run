---
status: planned
depends: [registry-publish, dormant-mode]
specs: []
issues: []
---

# Plan: Migrate the second origin deployment to the registry module (dormant candidate)

## Scope

**Cross-repo: executes in the second origin deployment's repo (private).** Replace
its vendored `tf/modules/dagster/` with the pinned registry module, and evaluate
flipping the stack to `dormant` mode outside demo windows — a fleet cost review
measured ~$70/month idle for this demo-shaped deployment, which dormant mode takes
to ~Cloud-SQL-only.

## Implements

Consumes this repo's published interface (own `specs:` empty).

## Approach

1. Start from the drafted migration on the local branch
   `test/dagster-module-superset` in that repo (deferred from
   [`reconcile-module-drift`](reconcile-module-drift.md)): root wiring onto the
   generalized maps + `dagster_moved.tf` are already plan-verified (0/0/0 with
   deployed image tags pinned). Swap the vendored module for the registry source
   and delete the applied `moved` blocks.
2. Confirm its private-ingress + path-prefix posture reproduces exactly (a proxying
   service in that stack depends on it).
3. Propose the dormant-mode flip with the wake procedure documented for demo days;
   apply if the stack owner accepts.

## Validation

- [ ] `tofu plan` after the swap: no-op or `moved`-explained
- [ ] Image-management posture decided and recorded: Terraform-mediated deploys (pass current image vars at apply) vs. gcloud-mediated with documented plan noise (deferred from [`reconcile-module-drift`](reconcile-module-drift.md))
- [ ] Proxied UI path (private ingress + path prefix) verified working post-migration
- [ ] HMAC-dependent flows (S3-compatible GCS reads) verified working
- [ ] Vendored module deleted in the same PR
- [ ] Dormant-mode decision recorded (adopted or declined, with idle-cost delta)

## Risks / unknowns

- **Demo timing** — don't migrate or go dormant inside an active demo window;
  coordinate with the stack owner.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
