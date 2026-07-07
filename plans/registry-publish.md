---
status: planned
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

1. Pre-publish sweep: no secrets/keys/consumer identifiers in tree or history;
   LICENSE, description, topics set.
2. Connect the repo to the Terraform Registry (org sign-in, publish flow) and tag
   `v0.1.0`.
3. Verify consumption from a scratch directory:
   `module "dagster" { source = "JarvusInnovations/dagster-cloud-run/google", version = "0.1.0" }`
   → `tofu init && tofu validate`.
4. README: registry-source usage snippet, mode ladder with costs, beta-provider
   caveat, support-scope statement (examples are the contract).

## Validation

- [ ] Registry page live with docs rendered from the repo
- [ ] `tofu init` resolves the module by registry source + version from a clean directory
- [ ] Pre-publish secret/identifier sweep recorded clean
- [ ] README contains a support-scope statement and pre-1.0 stability caveat

## Risks / unknowns

- **Registry org onboarding** — publishing under an org namespace requires a GitHub
  org admin to authorize the registry app; may need someone with org perms.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
