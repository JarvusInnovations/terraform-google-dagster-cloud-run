---
status: in-progress
depends: [land-pr-67]
specs: []
issues: []
---

# Plan: Reconcile vendored-module drift into a superset

## Scope

**Cross-repo: executes in `JarvusInnovations/gtfs-realtime-archiver`**
(`tf/modules/dagster/`), diffing against the second origin deployment's vendored
copy (private repo). Produce the single superset module that both production
deployments can run unchanged — the extraction source for
[`import-module`](import-module.md). The second repo is only read here; its
migration is [`migrate-second-consumer`](migrate-second-consumer.md).

## Implements

The ingress-posture, code-location, and generalization rules of
[specs/module-interface.md](../specs/module-interface.md) and
[specs/principles.md](../specs/principles.md#generic-over-project-named), upstream
(conformance audited in this repo after [`import-module`](import-module.md)).

## Approach

1. Adopt from the second copy: private-ingress + proxy mode (`public_ingress`),
   webserver `--path-prefix`, configurable `min_instance_count`, per-SA HMAC keys
   (`hmac.tf`) behind an opt-in flag.
2. Generalize consumer-named variables on both sides
   (`agencies_secret_id`, `protobuf_bucket_name`, `parquet_bucket_name`, and the
   second deployment's equivalents) into per-code-location `secret_grants`
   and `bucket_grants` maps. Choose map keys so existing IAM/HMAC resource addresses
   are preserved; where impossible, ship `moved` blocks.
3. Validate migration-neutrality: `tofu plan` in the archiver with the superset
   module vendored in; hand-written root-module diff for the second deployment
   proving its plan is no-op / moved-only.

## Validation

- [ ] Archiver `tofu plan` with the superset module: no-op or fully explained by `moved` blocks
- [ ] Second deployment's root-module diff drafted and its `tofu plan` no-op or moved-only (run by a maintainer with access)
- [ ] A sweep for consumer-domain identifiers (feed, bucket, and secret names from both origin deployments) finds no variable/resource names in the module (comments exempt)
- [ ] HMAC keys are opt-in and off by default; archiver plan unaffected by the flag's existence
- [ ] Private-ingress + path-prefix mode carried over with the second copy's behavior intact

## Risks / unknowns

- **`for_each` re-keying** — the riskiest mechanical step; wrong keys destroy/recreate
  live IAM bindings and HMAC keys. Mitigate with `moved` blocks and reviewed plans
  ([state addresses are the compatibility surface](../specs/principles.md#state-addresses-are-the-compatibility-surface)).
- **Demo posture leaking in** — the second copy hardcodes `min_instance_count = 1`
  ("demo posture"); superset must make that a variable defaulting to 0.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
