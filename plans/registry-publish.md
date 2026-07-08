---
status: done
pr: null
depends: [import-module, deployment-kit]
specs:
  - specs/architecture.md
issues: []
---

# Plan: Publish v0.1.0 to the Terraform Registry

## Scope

First public release: semver tag, registry publication under the JarvusInnovations
namespace, and the README brought to "adoptable by a stranger" quality. Pre-1.0 —
interface may still move, and the README says so.

Out of scope: consumer migrations (downstream plans), announcements
([`community-packaging`](community-packaging.md)).

## Implements

- [specs/architecture.md](../specs/architecture.md) — versioning & distribution

## Approach

1. ~~Pre-publish sweep~~ DONE 2026-07-07: no consumer identifiers or secret
   literals in tree or full history (27 commits, all fresh); LICENSE and
   description in place.
2. ~~README~~ DONE (landed with import-module/on-demand): registry-source usage
   snippet, mode ladder with costs, beta-provider note, support-scope statement.
3. **Maintainer runbook** (human-gated — publication acts):
   a. `git tag -a v0.1.0 -m "v0.1.0 — initial pre-release" && git push origin v0.1.0`
   b. Optionally `gh release create v0.1.0 --title v0.1.0 --notes-file <notes>`
      (release notes draft in the session log; a plain tag is enough for the
      registry).
   c. registry.terraform.io → Sign in with GitHub → Publish → Module → authorize
      the JarvusInnovations org for the registry GitHub App (org admin) → select
      `terraform-google-dagster-cloud-run`. The registry auto-detects tags.
4. Verify consumption from a scratch directory:
   `module "dagster" { source = "JarvusInnovations/dagster-cloud-run/google", version = "0.1.0" }`
   → `tofu init` resolves.

## Validation

- [x] Registry page live with docs rendered from the repo
- [x] `tofu init` resolves the module by registry source + version from a clean directory
- [x] Pre-publish secret/identifier sweep recorded clean
- [x] README contains a support-scope statement and pre-1.0 stability caveat

## Risks / unknowns

- **Registry org onboarding** — publishing under an org namespace requires a GitHub
  org admin to authorize the registry app; may need someone with org perms.

## Notes

- No PR — publication was tag + registry flow on main (pr: null).
- v0.1.0 live on registry.terraform.io as
  `JarvusInnovations/dagster-cloud-run/google/0.1.0`; consumption verified from a
  clean directory (`tofu init` downloads 0.1.0, `tofu validate` passes).
- **Two-registry nuance discovered at verification**: OpenTofu resolves bare
  registry sources against registry.opentofu.org, a separately-indexed registry —
  the bare source 404s there until the module is submitted (opentofu/registry
  issue form; automation opens the PR and then indexes all GitHub tags). Until
  that lands, tofu consumers use the explicit host form:
  `source = "registry.terraform.io/JarvusInnovations/dagster-cloud-run/google"`.

## Follow-ups

- Tracked as: OpenTofu registry submission (opentofu/registry module issue form) —
  makes the bare source resolve for tofu users; both migration plans note the
  explicit-host workaround until then.
