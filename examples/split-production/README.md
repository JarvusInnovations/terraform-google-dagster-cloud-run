# split-production

The full `split` topology behind IAP: webserver Service (scales 0→N), daemon
Worker Pool (singleton), a gRPC code-server Service per code location, and a
run-worker Job per code location — see the root README's
["Deployment modes"](../../README.md#deployment-modes) table for the cost
shape (~$100/mo in practice; the always-on daemon keeps the code server
permanently warm).

Unlike `consolidated-starter`, this shape supports any number of
`code_locations` and demonstrates consumer-domain wiring
(`extra_env`/`bucket_grants`) without forking the module — see `main.tf`.

## How this differs from consolidated-starter

- **Ingress**: IAP-gated (`iap_allowed_domain` + `project_number` +
  `custom_domain`), not private. See the module-interface's
  ["Ingress postures"](../../specs/module-interface.md#ingress-postures-webserver).
- **Topology**: each component is its own Cloud Run resource, not three
  containers in one Service — reachable at its own URL/gRPC endpoint rather
  than `localhost`.
- **Multiple code locations**: `code_locations` can have any number of
  entries; each gets its own code-server image, run-worker Job, and
  `CODE_SERVER_HOST_<KEY>` env var. Repeat the `kit/workspace.yaml.tmpl` and
  `kit/dagster.yaml.tmpl` blocks per location (see the `analytics` example in
  both templates' comments).

## Walk-through

The build → apply → wire-config → open-UI mechanics are identical to
[`consolidated-starter`](../consolidated-starter/README.md) — follow that
walk-through, substituting this directory's variables (an IAP domain instead
of private ingress, and as many `code_locations` entries as you need). The
only genuinely new step is granting IAP access: after `tofu apply`, add the
principals who should reach the UI via
`iap_allowed_domain`/`google_iap_web_type_compute_iam_member`-style bindings
in your own Terraform, or through the IAP console for a quick check.
