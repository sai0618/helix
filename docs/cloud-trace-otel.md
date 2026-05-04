# Cloud Trace With OpenTelemetry

The `user-portal` Flask app emits OpenTelemetry traces to Google Cloud Trace.

## What Is Instrumented

- Flask HTTP server requests through `opentelemetry-instrumentation-flask`.
- PyMySQL database calls through `opentelemetry-instrumentation-pymysql`.
- Manual application spans for user CRUD operations:
  - `users.list`
  - `users.get`
  - `users.create`
  - `users.update`
  - `users.delete`

Structured JSON logs include trace correlation fields:

```text
trace_id
span_id
trace_sampled
logging.googleapis.com/trace
logging.googleapis.com/spanId
logging.googleapis.com/trace_sampled
```

## Required GCP API

Terraform already includes:

```text
cloudtrace.googleapis.com
```

You can also enable/check it manually:

```bash
gcloud services enable cloudtrace.googleapis.com \
  --project PROJECT_ID

gcloud services list --enabled \
  --project PROJECT_ID \
  --filter='name:cloudtrace.googleapis.com'
```

## Required IAM Roles

To view Trace Explorer:

```text
roles/cloudtrace.user
```

To write traces from workloads:

```text
roles/cloudtrace.agent
```

The Terraform persona model includes `roles/cloudtrace.user` for Dev, Ops, and SRE personas, and `roles/cloudtrace.agent` for the GKE node and UI workload service accounts. In Google Cloud Sandbox projects, project IAM changes may still be blocked unless `create_project_iam_bindings = true` and the active user has `resourcemanager.projects.setIamPolicy`.

Use the helper script for sandbox setup checks:

```bash
scripts/configure_cloud_trace.sh \
  --project-id PROJECT_ID
```

The normal new-sandbox setup runs this automatically:

```bash
./setup_new_sandbox.sh \
  --project-id PROJECT_ID \
  --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL \
  --build-mode docker
```

The script:

- Enables Cloud Trace API.
- Attempts to grant `roles/cloudtrace.user` to the active Google user.
- Attempts to grant `roles/cloudtrace.agent` to the default Compute Engine service account.
- Attempts to grant `roles/cloudtrace.agent` to the `helix-user-portal` Workload Identity principal.
- Grants `roles/iam.workloadIdentityUser` on the default Compute Engine service account to the `helix-user-portal` Kubernetes service account.
- Prints current Trace IAM bindings.

In Google Cloud Sandbox projects, project-level IAM grants can fail with `setIamPolicy` denied. The fallback used here is Workload Identity impersonation: the pod is annotated to impersonate the default Compute Engine service account, and secret-level IAM grants allow that service account to mount Secret Manager values.

## Helm Settings

Tracing is enabled by default in the `user-portal` chart:

```yaml
tracing:
  enabled: true
  projectId: ""
  sampleRate: "1.0"
```

The deployment sets:

```text
OTEL_TRACES_ENABLED
OTEL_TRACES_SAMPLE_RATE
OTEL_EXPORTER_GCP_TRACE_PROJECT_ID
```

The deployment scripts set `tracing.projectId` to the current Google Cloud Sandbox project ID.
They also set this Kubernetes service account annotation:

```yaml
iam.gke.io/gcp-service-account: PROJECT_NUMBER-compute@developer.gserviceaccount.com
```

That annotation is required because GKE otherwise presents the pod as the raw workload identity pool principal, which can produce Cloud Trace `PERMISSION_DENIED` exporter errors.

The smoke test script verifies this after deployment:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/test_new_sandbox_apps.sh
```

## Build And Deploy

After changing app instrumentation:

```bash
scripts/build_new_sandbox_images.sh --mode docker

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/deploy_new_sandbox_apps.sh
```

Generate traffic:

```bash
curl http://helix.<EXTERNAL_IP>.sslip.io/healthz
```

Then open:

```text
Google Cloud Console -> Trace Explorer
```

Select the Google Cloud Sandbox project and filter by service:

```text
user-portal
```

Trace export can take a few minutes after traffic is generated.
