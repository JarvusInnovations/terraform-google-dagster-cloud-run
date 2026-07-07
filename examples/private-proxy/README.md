# private-proxy

`split` topology with the webserver fully private (no IAP, no public
invoker) and served under a URL `path_prefix`, for consumers who front
Dagster with their own reverse-proxying service (another Cloud Run service,
a gateway, etc.) rather than exposing it via IAP or `allUsers`. See the
module-interface's
["Ingress postures"](../../specs/module-interface.md#ingress-postures-webserver),
posture 3.

## How this differs from consolidated-starter

- **Ingress**: `iap_allowed_domain = null`, `public_ingress = false` — no
  invoker binding is created by the module at all. `main.tf` grants
  `roles/run.invoker` directly to `var.proxy_service_account_email`, the one
  binding the module deliberately leaves to the consumer.
- **`path_prefix = "/dagster"`**: passed to `dagster-webserver
  --path-prefix` so UI-generated URLs match whatever subpath your proxy
  forwards. If your proxy mounts Dagster somewhere else, change this to
  match.
- **`webserver_min_instances = 1`**: keeps the webserver warm so the proxy
  hop doesn't eat a cold start on every UI visit.
- **Topology**: same `split` shape as `split-production` (webserver/daemon/
  code-server as separate Cloud Run resources), not consolidated.

## Walk-through

Build and apply mechanics are identical to
[`consolidated-starter`](../consolidated-starter/README.md) — follow that
walk-through for the image build, `dagster.yaml`/`workspace.yaml` wiring, and
`tofu apply`. What's different here is how you reach the UI afterward: there
is no `gcloud run services proxy` step and no public URL. Your own proxying
service (its service account is `var.proxy_service_account_email`) is what
Cloud Run IAM allows to invoke the webserver — point it at
`module.dagster.webserver_url` with a Google ID token for that service
account, forwarding whatever path your `path_prefix` matches. Test the
binding directly first if you want to confirm it before wiring the proxy:

```sh
curl -H "Authorization: Bearer $(gcloud auth print-identity-token \
  --impersonate-service-account=<proxy_service_account_email> \
  --audiences=$(tofu output -raw webserver_url))" \
  "$(tofu output -raw webserver_url)/dagster/server_info"
```
