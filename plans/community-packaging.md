---
status: planned
depends: [registry-publish, migrate-gtfs-archiver]
specs: []
issues: []
---

# Plan: Community packaging & announcement

## Scope

Make the module discoverable where Dagster-on-GCP users already look. Partly
**cross-repo** (a docs PR to `dagster-io/community-integrations`).

Explicitly out of scope by maintainer decision (2026-07-07): volunteering a
CODEOWNERS entry for `dagster-contrib-gcp` — docs contribution only, no ownership
commitment. Revisit later if stewardship appetite changes.

## Implements

No specs — distribution work.

## Approach

1. PR to `dagster-io/community-integrations`: add a "Deploying Dagster to Cloud Run"
   section to `libraries/dagster-contrib-gcp/README.md` linking the registry module
   (this directly answers their issue #133, which asked for deployment guidance and
   got only a third-party demo repo); optionally tidy the library's stale CHANGELOG
   while there.
2. Announce in Dagster Slack (#integrations, #show-and-tell) once the archiver runs
   on the published module in production — lead with the cost ladder and the
   three-mode toggle.
3. Optional follow-on: a Dagster docs deployment-guide PR and/or a short write-up of
   the split/consolidated/on-demand cost ladder.

## Validation

- [ ] community-integrations README PR opened, linking the registry module, referencing issue #133
- [ ] Slack announcement posted after production migration is live
- [ ] Module README shows the registry badge/source and the origin deployments as references

## Risks / unknowns

- **Upstream review latency** — the docs PR needs a community-integrations
  maintainer; keep it small and self-contained so it's easy to accept.
- **Support expectations** — announcing invites issues; the support-scope statement
  from [`registry-publish`](registry-publish.md) must be in place first.

## Notes

(Populated at closeout.)

## Follow-ups

(Populated at closeout.)
