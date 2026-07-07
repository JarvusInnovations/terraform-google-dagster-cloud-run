---
status: done
pr: 1
depends: [reconcile-module-drift]
specs:
  - specs/architecture.md
  - specs/module-interface.md
issues: []
---

# Plan: Import the superset module into this repo

## Scope

Bring the reconciled module into this repo at the Terraform Registry standard layout
(module at root), with examples and CI. Fresh files, fresh history — no git-history
import from the archiver (its history brushes against untracked service-account
keys; a clean start is the safe posture).

Out of scope: `dormant` mode ([`dormant-mode`](dormant-mode.md)), kit templates
([`deployment-kit`](deployment-kit.md)), tagging/registry
([`registry-publish`](registry-publish.md)).

## Implements

- [specs/architecture.md](../specs/architecture.md) — repo structure, provider
  posture, CI gates
- [specs/module-interface.md](../specs/module-interface.md) — the full `split` +
  `consolidated` interface as reconciled upstream

## Approach

1. Copy the superset `tf/modules/dagster/*.tf` to repo root; rename/organize per
   registry conventions (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`,
   component files).
2. Write `examples/consolidated-starter/`, `examples/split-production/`,
   `examples/private-proxy/` — each a minimal root module invoking this module.
3. GitHub Actions: `tofu fmt -check -recursive`, `tofu validate` (root + each
   example) on PR; document the sandbox-project plan step as a follow-on when
   credentials exist.
4. Module README: component table, mode ladder with cost floors and break-evens,
   ingress postures, the workspace coupling rule, beta-provider caveat.
5. Negative-case check for the consolidated single-location precondition, and a
   sandbox apply of `consolidated-starter` to apply-verify fractional CPU + probes
   (deferred from [`land-pr-67`](land-pr-67.md) — Cloud Run enforces these at
   apply, never at plan/validate).

## Validation

- [x] `tofu validate` passes at root and in each of the three examples
- [x] CI workflow runs fmt + validate on PR and is green
- [x] Repo satisfies registry structural requirements (root module, LICENSE, README, `terraform-google-*` name)
- [x] README documents every `deployment_mode` with its cost floor and break-even
- [x] No consumer-domain identifiers anywhere in module code or examples
- [x] Consolidated mode with two code locations fails at plan with the precondition message (deferred from [`land-pr-67`](land-pr-67.md))
- [ ] `consolidated-starter` example apply-verified in a sandbox project (fractional per-container CPU + startup probes accepted by the Cloud Run API) (deferred from [`land-pr-67`](land-pr-67.md))

## Risks / unknowns

- **Validate-only CI is weak assurance** — Cloud Run rejects things offline checks
  pass ([production deployments are the test bed](../specs/principles.md#production-deployments-are-the-test-bed));
  real confidence comes from the migration plans downstream.

## Notes

- The sandbox-apply criterion stays unchecked: no designated sandbox GCP project
  exists yet, and consolidated mode remains plan/validate-verified only. Cloud
  Run enforces fractional-CPU and probe rules at apply.
- Extraction deltas from the upstream superset: `google-beta` declared in
  `required_providers` (was implicit via the consumer root — would have broken
  registry consumers), and an unused `data.google_project` removed, which is
  also what makes create-only CI plans work offline (no API calls).
- CI gotcha: `*.tfvars` is gitignored, so the negative-test fixture needed an
  explicit exception — it was silently absent from the first push and CI
  failed with "Failed to read variables file". Placeholder-only fixtures need
  gitignore exceptions.
- README table lists `dormant` as *(planned)* — flip it when the dormant-mode
  plan lands.

## Follow-ups

- Tracked as: consolidated-mode sandbox apply — needs a designated sandbox GCP
  project; until then the fractional-CPU sizing carries the documented
  whole-CPU fallback. Revisit at `registry-publish` or first greenfield
  consumer.
