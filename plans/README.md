# Plans

Specs (`specs/`) describe **state** — what should be true. Plans here describe
**motion** — the work-in-flight DAG bringing code into conformance. One file per
bounded chunk of work; frontmatter (`status`, `depends`, `specs`, `awaits`) is the
single source of truth for the graph.

Full protocol: [specops plans-protocol](../.agents/skills/specops/references/plans-protocol.md).

Query the DAG (never hand-maintain a drawing here):

```sh
.agents/skills/specops/scripts/specops        # dashboard
.agents/skills/specops/scripts/specops next   # what to work on
.agents/skills/specops/scripts/specops dag    # Mermaid graph
```

Note: several plans in this DAG execute in *other* repos
(`gtfs-realtime-archiver`, a second origin deployment's private repo,
`dagster-io/community-integrations`).
Those are marked cross-repo in their Scope and must not be auto-executed by
parallel worktree agents — they need a human-attended session in the target repo.
