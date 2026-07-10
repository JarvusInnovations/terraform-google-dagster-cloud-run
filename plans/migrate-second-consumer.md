---
status: done
pr: null
depends: [registry-publish, on-demand-mode]
specs: []
issues: []
---

# Plan: Migrate the second origin deployment to the registry module (on-demand candidate)

## Scope

**Cross-repo: executes in the second origin deployment's repo (private).** Replace
its vendored `tf/modules/dagster/` with the pinned registry module, and evaluate
flipping the stack to `on-demand` mode — a fleet cost review measured ~$70/month
idle for this demo-shaped deployment, which on-demand takes to ~Cloud-SQL-only
while keeping the UI reachable (cold start on first visit, no apply needed to wake).

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
3. Propose the on-demand-mode flip (this was the mode's motivating deployment —
   archiver PR #70 was authored for it); apply if the stack owner accepts. Note
   the mode change collapses its split resources into the single-instance Service.

**Source note**: until the OpenTofu registry submission lands (see
[`registry-publish`](registry-publish.md) follow-ups), use the explicit host form
`source = "registry.terraform.io/JarvusInnovations/dagster-cloud-run/google"` —
the bare source 404s on registry.opentofu.org.

## Validation

- [x] `tofu plan` after the swap: no-op or `moved`-explained
- [x] Image-management posture decided and recorded: Terraform-mediated deploys (pass current image vars at apply) vs. gcloud-mediated with documented plan noise (deferred from [`reconcile-module-drift`](reconcile-module-drift.md))
- [x] Proxied UI path (private ingress + path prefix) verified working post-migration
- [x] HMAC-dependent flows (S3-compatible GCS reads) verified working
- [x] Vendored module deleted in the same PR
- [x] On-demand-mode decision recorded (adopted or declined, with idle-cost delta)

## Risks / unknowns

- **Demo timing** — don't migrate or flip modes inside an active demo window;
  coordinate with the stack owner.

## Notes

- Landed across udda PRs #134/#137/#138/#139 (pr: null — multi-PR migration) and
  module releases v0.2.0→v0.3.1, all in one recovery-driven day. The flip was the
  module's first real single-instance apply and surfaced four apply-time-only
  Cloud Run rules (sizing coupling, ≥1 vCPU always-allocated total, managed
  Cloud SQL volume non-functional in multicontainer → Auth Proxy sidecar,
  reserved "cloudsql" volume name) — each encoded upstream.
- Also surfaced: the shared-pg cutover had granted cloudsql.client to primary
  SAs only; both run-worker SAs granted imperatively (Chris-authorized,
  2026-07-09). Failure signature documented in the module README.
- Image posture decision: kept gcloud-mediated CI deploys; variable defaults
  synced to the deployed tags at migration (0.20.1) so local plans stay quiet
  until the next release rots them again — acceptable for a low-touch stack.
- Wake test: workspace over localhost gRPC ✓; authenticated /dagster proxy 200 ✓;
  materialization + HMAC dbt seed run SUCCESS via run-worker Jobs ✓;
  scale-to-zero confirmed with a measured **69.5s cold wake** after 25 min idle
  (~300ms warm). Idle Cloud Run cost now ~$0 (shared Cloud SQL tenant remains).
- CDPHE bid was lost (2026-07-09), which removed the demo-window constraint and
  motivated the immediate flip.

## Follow-ups

- Tracked as: the imperative cloudsql.client grants for both run-worker SAs need
  a durable home in the infra-ops shared-postgres config (cross-referenced in
  the HQ open-source-infrastructure timeline).
- Tracked as: document/measure the on-demand cold wake (~70s) in the module
  README; in-process code loading as a future optimization is already noted on
  the on-demand-mode plan.
