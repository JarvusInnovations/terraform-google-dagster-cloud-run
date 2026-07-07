# consolidated-starter

The cheapest way to get Dagster running on Cloud Run: webserver, daemon, and a
single code server share one always-on Cloud Run Service (~$55/mo at the
default 1 vCPU / 2.5Gi sizing, on top of the Cloud SQL instance). See the root
README's ["Deployment modes"](../../README.md#deployment-modes) table for how
this compares to `split` and `on-demand`.

This walk-through goes from a clone of this repo to a loaded Dagster UI,
using only [`kit/`](../../kit/README.md), this module, and standard tooling
(`docker`, `tofu`/`terraform`, `gcloud`, `uv`). It's honest about the parts
that need a real GCP project — there's no way to exercise Cloud Run, Cloud
SQL, or Artifact Registry without one.

## Prerequisites

- A GCP project with billing enabled, and `gcloud auth login` /
  `gcloud config set project <project>` done.
- An Artifact Registry Docker repository to push images to (`gcloud artifacts
  repositories create dagster --repository-format=docker
  --location=us-central1`), plus `gcloud auth configure-docker
  us-central1-docker.pkg.dev`.
- `docker`, [`uv`](https://docs.astral.sh/uv/), and OpenTofu or Terraform
  ≥ 1.6 installed locally.
- The APIs this module needs enabled on the project: `run.googleapis.com`,
  `sqladmin.googleapis.com`, `secretmanager.googleapis.com`,
  `iam.googleapis.com`, `artifactregistry.googleapis.com`.

## 1. Start your Dagster project

If you don't already have one, the minimum viable layout is a
`pyproject.toml`, a lockfile, and a `Definitions` object:

```
my-pipeline/
├── pyproject.toml
├── uv.lock
└── my_pipeline/
    ├── __init__.py
    └── definitions.py       # exports `defs = dg.Definitions(...)`
```

`uv add dagster dagster-webserver dagster-gcp` gets you the packages every
target needs; add your pipeline's own dependencies (`dagster-contrib-gcp`
is only needed at runtime by the run launcher config below, not imported by
your code).

## 2. Wire up the kit

Copy the kit into your project and fill in the location-key placeholder:

```sh
mkdir -p deploy
cp <path-to-this-repo>/kit/Containerfile ./Containerfile
cp <path-to-this-repo>/kit/dagster.yaml.tmpl deploy/dagster.yaml
cp <path-to-this-repo>/kit/workspace.yaml.tmpl deploy/workspace.yaml
```

The templates already default to the location key `pipeline`, which is what
this example's Terraform (`variables.tf`) uses too — if you keep that key,
there's nothing to edit. If you want a different key (say, your pipeline is
actually called `analytics`), replace every `pipeline`/`PIPELINE` in
`deploy/dagster.yaml` and `deploy/workspace.yaml` with `analytics`/`ANALYTICS`
(a single `sed -i 's/pipeline/analytics/g; s/PIPELINE/ANALYTICS/g'
deploy/dagster.yaml deploy/workspace.yaml` does it). See
[`kit/README.md`](../../kit/README.md#how-this-relates-to-the-module-the-workspace-coupling-rule)
for why the key has to match in three places.

Add a `.dockerignore` excluding `.venv/`, `.git/`, and anything else you
don't want in the build context.

## 3. Build and push the three images

```sh
export REGISTRY=us-central1-docker.pkg.dev/<project>/dagster
export TAG=$(git rev-parse --short HEAD)

docker build --target webserver   -t "$REGISTRY/dagster-webserver:$TAG"   .
docker build --target daemon      -t "$REGISTRY/dagster-daemon:$TAG"      .
docker build --target code-server -t "$REGISTRY/dagster-code-server:$TAG" \
  --build-arg DAGSTER_MODULE_NAME=my_pipeline.definitions .

docker push "$REGISTRY/dagster-webserver:$TAG"
docker push "$REGISTRY/dagster-daemon:$TAG"
docker push "$REGISTRY/dagster-code-server:$TAG"
```

Tagging/pushing is your CI's job long-term (see
[`kit/README.md#image-tagging`](../../kit/README.md#image-tagging)); doing it
by hand here is just to get the walk-through moving.

## 4. `tofu apply`

From this directory:

```sh
tofu init

tofu apply \
  -var project_id="<project>" \
  -var webserver_image="$REGISTRY/dagster-webserver:$TAG" \
  -var daemon_image="$REGISTRY/dagster-daemon:$TAG" \
  -var code_locations='{
    pipeline = {
      image             = "'"$REGISTRY"'/dagster-code-server:'"$TAG"'"
      module_name       = "my_pipeline.definitions"
      port              = 3030
      run_worker_cpu    = "1"
      run_worker_memory = "2Gi"
    }
  }'
```

(A `terraform.tfvars` file is easier to iterate with than a one-line `-var`
for `code_locations` — either works.) This creates a `db-f1-micro` Cloud SQL
instance plus the module's Cloud Run Service, run-worker Job, service
accounts, secrets, and logs bucket. The webserver is **private by default**
(no IAP, no public invoker) — see step 6 for how to reach it.

Confirm the run-worker Job name matches what you put in `deploy/dagster.yaml`:

```sh
tofu output run_worker_job_names
# { "pipeline" = "dagster-run-worker-pipeline" }
```

It's deterministic (`dagster-run-worker-<key>`), so you can fill in
`deploy/dagster.yaml` before the first apply rather than looping back to
edit it afterward.

## 5. If you changed the location key after building

`dagster.yaml`/`workspace.yaml` are baked into the images (they're not
runtime-mounted), so a location-key change requires rebuilding and re-pushing
the `code-server` (and, since `job_name_by_code_location` lives in
`dagster.yaml`, also `webserver` and `daemon`) images, then `tofu apply`
again with the new tags.

## 6. Open the UI

The webserver is private, so reach it with an authenticated local proxy
rather than opening the `run.app` URL directly. In `consolidated` mode the
module always names the Service `dagster`:

```sh
gcloud run services proxy dagster --region=<region> --project=<project>
```

This opens `http://127.0.0.1:8080` forwarding to the Cloud Run service with
your `gcloud` identity's credentials. You should see the Dagster UI with the
`pipeline` code location loaded and `hello_asset` (or whatever your
`definitions.py` exports) in the asset graph.

For a throwaway sandbox where authenticated proxying is overkill, you can
instead set `-var public_ingress=true` in step 4 (unauthenticated — never do
this for anything real) or grant yourself `roles/run.invoker` on the service
and open `tofu output webserver_url` directly.

## Troubleshooting

- **Code location fails to load in the UI** — check the code-server's Cloud
  Run logs; a mismatched `location_name`/`CODE_SERVER_HOST_<KEY>` shows up as
  a gRPC connection error.
- **Runs stay queued forever** — check the daemon's logs; "No run launcher
  defined for code location" means the `job_name_by_code_location` key in
  `dagster.yaml` doesn't match `workspace.yaml`'s `location_name`.
- **`tofu apply` rolls back your webserver/daemon version** — you passed a
  stale image tag; see the root README's
  ["Images move with your deploys"](../../README.md#images-move-with-your-deploys--dont-apply-with-stale-pins).
