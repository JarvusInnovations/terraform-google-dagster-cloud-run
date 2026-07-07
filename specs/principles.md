# Principles

The project's philosophy, written down as principles. Each is decisive: it picks a
side of a real trade-off so an implementer can resolve an unspecified case the way
the author would.

## State addresses are the compatibility surface

Variable names, defaults, and outputs may change freely before `v1.0.0`. Resource
addresses and `for_each`/`count` keys may not — a change that would destroy and
recreate a consumer's running infrastructure requires `moved` blocks in the same
release, or doesn't ship. Both origin deployments (gtfs-realtime-archiver and a
second production stack in a private repo) must be able to adopt any release with a plan that is a
no-op or fully explained by `moved` blocks. When a cleaner design conflicts with a
churn-free migration, the migration wins.

## Generic over project-named

No variable, resource, or output may encode a consumer's domain. The module was
extracted from deployments that had `agencies_secret_id`, `protobuf_bucket_name`,
and similar consumer-named variables baked in — that shape is the failure mode. Consumer-specific
capabilities are expressed as generic maps (per-code-location secret grants, bucket
grants) so the next consumer configures instead of forking.

## Cost transparency over cost marketing

Every deployment mode documents its always-on floor and the break-even against the
adjacent mode, in dollars, with the assumptions stated. Defaults are sized for the
greenfield starter, not the largest known consumer. A consumer flipping a mode toggle
must be able to predict the bill direction from the README alone — a fleet cost
review found `consolidated` at its then-default sizing was a wash against `split`,
which is exactly the surprise this principle exists to prevent.

## Production deployments are the test bed

A topology or interface change ships only after a real `tofu plan` (and for behavior
changes, an apply) against at least one of the origin production stacks. CI's
`fmt`/`validate` and example plans catch syntax, not truth — Cloud Run rejects
configurations (probe timing, sidecar billing modes) that pass every offline check.

## Modes are rungs, not forks

`deployment_mode` values are stops on one scaling ladder, not divergent products. A
deployment moves between modes by changing the toggle (plus mode-specific sizing
variables) — never by rewriting its `code_locations`, secrets, ingress, or database
config. Shared infrastructure (Cloud SQL, buckets, service accounts, run workers) is
identical across modes. A feature that only works in one mode must fail fast with a
precondition, not degrade silently.

## Terraform is the image mover — never ignore image changes

Image tags move *through* Terraform: the proven origin pattern is a release CI job
that runs `tofu apply` with image variables derived from the release tag. The module
must therefore **never** put `lifecycle ignore_changes` on image fields — that would
silently break every Terraform-mediated deploy, and `ignore_changes` cannot be made
conditional, so one consumer's convenience would be another's outage. The corollary
risk (an apply with stale image variables rolling back production) is a consumer
workflow concern: the module README and examples must warn that plans/applies always
supply current image versions, and consumers keep local tfvars pins in sync with
their latest release.
