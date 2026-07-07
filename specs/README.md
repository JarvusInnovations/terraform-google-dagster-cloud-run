# Specs

This project uses spec-driven development ([specops](../.agents/skills/specops/SKILL.md)).
Specs declare the complete desired state of the module; implementation follows spec.
All work begins with a spec update.

## Layout

```
specs/
├── README.md            # This file
├── principles.md        # Project-wide decisive principles
├── architecture.md      # Repo structure, provider posture, CI, versioning
├── module-interface.md  # The module's variable surface, deployment modes, outputs
└── deployment-kit.md    # Container image + Dagster config templates shipped alongside
```

This is an infrastructure module, not an app — there are no `screens/` or `api/`
directories. The equivalent of an API contract here is `module-interface.md`: the
variables, modes, and outputs consumers program against.

## Workflow

1. Propose what should be true as a spec change (its own PR)
2. Review and accept the spec
3. Author or update a plan in `plans/` to bring code into conformance
4. Implement, verify against the spec, close the plan out

Spec↔code divergence is a bug, not debt.
