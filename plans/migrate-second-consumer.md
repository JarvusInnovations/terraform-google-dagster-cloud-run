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

1. Same source-swap mechanics as [`migrate-gtfs-archiver`](migrate-gtfs-archiver.md),
   plus mapping its bespoke variables (data bucket, API-credential secret vars, HMAC
   usage) onto the generalized `secret_grants` / `bucket_grants` / HMAC flag.
2. Confirm its private-ingress + path-prefix posture reproduces exactly (a proxying
   service in that stack depends on it).
3. Propose the dormant-mode flip with the wake procedure documented for demo days;
   apply if the stack owner accepts.

## Validation

- [ ] `tofu plan` after the swap: no-op or `moved`-explained
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
