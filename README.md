# terraform-google-dagster-cloud-run

Deploy open-source [Dagster](https://dagster.io) on Google Cloud Run — fully
serverless, no GKE cluster, no VMs.

> **Status: pre-release.** The module is being extracted from two production
> deployments and is not yet published to the Terraform Registry. Interfaces
> will change until `v1.0.0`.

## What it deploys

| Component | Cloud Run shape |
| --- | --- |
| Dagster webserver (UI) | Service (IAP-gated, public, or private + proxy) |
| Dagster daemon | Worker Pool (singleton) |
| Code server(s) | Service per code location (internal gRPC) |
| Run workers | Jobs, launched per-run via [`dagster-contrib-gcp`](https://github.com/dagster-io/community-integrations/tree/main/libraries/dagster-contrib-gcp)'s `CloudRunRunLauncher` |
| Run/event storage | Cloud SQL (Postgres) |

## Deployment modes

One `deployment_mode` variable selects the topology, so a deployment can move
between rungs without rewriting its config:

- **`split`** — every component its own Cloud Run resource. Horizontal
  webserver scaling, isolated daemon, independently deployable code locations.
- **`consolidated`** — webserver + daemon + code server as three containers in
  one always-on Service. The minimal Dagster-native starter (single code
  location) for the lowest always-on floor.
- **`dormant`** *(planned)* — daemon stopped, everything scaled to zero.
  ~$0/month idle for demos and staging; wake on demand.

## Origin

Extracted from the Dagster deployments behind
[gtfs-realtime-archiver](https://github.com/JarvusInnovations/gtfs-realtime-archiver)
(gtfsrt.io) and a second production data platform, where earlier versions of
this module run in production. Built and maintained by
[Jarvus Innovations](https://jarv.us).

## License

[Apache-2.0](LICENSE)
