# Project Implementation

This document is the main implementation guide for building the Helix platform in a Google Cloud Sandbox project. It covers the Terraform resource sequence, application build flow, observability setup, deployment steps, and validation.

Related docs:

- [Architecture](architecture.md)
- [BigQuery Schema And Grafana Queries](bigquery-grafana.md)
- [Design Decisions](design-decisions.md)

## Terraform Resource Sequence

Terraform provisions infrastructure in this order:

1. **State bucket bootstrap**
   - Creates a GCS bucket for Terraform remote state.
   - Writes `backend.hcl` for the sandbox environment.

2. **Project services**
   - Enables required Google Cloud APIs, including Compute Engine, GKE, Artifact Registry, Secret Manager, Cloud Logging, Cloud Monitoring, Cloud Trace, BigQuery, IAM, Cloud Resource Manager, and Service Networking.

3. **IAM and service accounts**
   - Creates named service accounts for GKE nodes, workloads, and CI/CD.
   - Project-level role bindings are optional because some Google Cloud Sandbox projects restrict project IAM policy updates.

4. **Networking**
   - Creates the VPC.
   - Creates segregated subnets for primary GKE, secondary GKE, load balancers, and operations.
   - Creates secondary ranges for GKE pods and services.

5. **Private Service Access**
   - Reserves an internal IP range for Google managed services.
   - Creates the service networking connection used by services such as Cloud SQL.

6. **Cloud NAT**
   - Creates regional Cloud Routers and Cloud NAT for outbound internet egress from private GKE nodes.

7. **Firewall rules**
   - Allows internal VPC, pod, and service traffic.
   - Keeps optional admin source ranges empty by default.

8. **Artifact Registry**
   - Creates Docker and Helm repositories used by image build and deployment scripts.

9. **GKE clusters**
   - Creates minimal primary and secondary zonal GKE clusters.
   - Enables Cloud Logging, Cloud Monitoring, Managed Service for Prometheus, and Secret Manager CSI.
   - Uses low node capacity suitable for a sandbox environment.

10. **Secret Manager**
    - Creates app login and MySQL credential secrets.
    - Grants access to the user-portal Kubernetes workload identity and to the Google service account used for trace export.

11. **Ingress foundation**
    - Reserves the global external IP used by the GKE Ingress.

12. **Observability log exports**
    - Creates BigQuery datasets for application logs and GKE logs.
    - Creates Cloud Logging sinks for structured app logs, node logs, and control-plane logs.
    - Grants BigQuery dataset viewer access to the configured user and Grafana service account.

Run the full infrastructure flow through the top-level setup script:

```bash
./setup_new_sandbox.sh \
  --project-id PROJECT_ID \
  --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL \
  --build-mode docker
```

## Application Build

The deployed application layer has two images:

- `user-portal`: Flask/Jinja2 UI and REST API.
- `user-data`: MySQL seed image containing initialization SQL.

The build flow is:

1. Read project and version settings from `.helix-sandbox.env`.
2. Build `apps/user-portal` and `apps/user-data`.
3. Tag images with the configured version, for example `v1`.
4. Push images to Artifact Registry.
5. Also tag and push `latest`.

For Google Cloud Sandbox projects, prefer local Docker builds because Cloud Build permissions can be restricted:

```bash
scripts/build_new_sandbox_images.sh --mode docker
```

The one-command setup runs this automatically unless `--skip-build` is passed.

## Observability And Traces

The platform uses Google Cloud observability and Grafana Cloud:

- User portal emits structured JSON logs.
- Cloud Logging sinks export app and GKE logs to BigQuery.
- Grafana Cloud BigQuery datasource reads golden-signal panels from exported logs.
- Grafana Cloud Monitoring datasource can read GKE CPU and memory metrics.
- User portal emits OpenTelemetry traces to Google Cloud Trace.

Trace setup is part of the normal setup flow:

1. `cloudtrace.googleapis.com` is enabled.
2. `scripts/configure_cloud_trace.sh` configures Workload Identity impersonation for `helix/helix-user-portal`.
3. `scripts/deploy_apps_to_gke.sh` annotates the Helm-managed Kubernetes service account with the Compute Engine default service account.
4. Terraform grants Secret Manager access to both the raw workload identity principal and the impersonated Google service account.
5. `scripts/test_new_sandbox_apps.sh` checks the pod identity and fails if recent logs contain Cloud Trace permission errors.

Expected pod trace identity:

```text
PROJECT_NUMBER-compute@developer.gserviceaccount.com
```

Open Trace Explorer in the same project and use a recent time range after the app deployment.

## Prerequisites

- You are logged in with `gcloud auth login`.
- Terraform, gcloud, kubectl, Helm, Docker, bq, and curl are installed.
- Docker Desktop is running for local Docker builds.
- The Google Cloud Sandbox project is active and ready for API enablement.
- Commands are run from the repository root.

Check the active account:

```bash
gcloud auth list
```

## One Command Setup

Run:

```bash
./setup_new_sandbox.sh \
  --project-id PROJECT_ID \
  --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL \
  --build-mode docker
```

The script performs these phases:

1. Sets the active gcloud project.
2. Deletes local Terraform cache and state pointers for the previous sandbox.
3. Writes `.helix-sandbox.env`, Terraform `terraform.tfvars`, and `backend.hcl`.
4. Creates the Terraform GCS state bucket.
5. Applies Terraform infrastructure.
6. Fetches GKE credentials for both clusters.
7. Configures Cloud Trace and Grafana BigQuery access.
8. Creates `credentials/compute-default-service-account-key.json` for Grafana Cloud BigQuery.
9. Builds and pushes app images.
10. Deploys MySQL and `user-portal` Helm releases.
11. Creates or updates the external GKE Ingress.
12. Tests pods, services, ingress, `/healthz`, app URL, trace identity, and recent trace exporter errors.

Generated runtime values are written to `.helix-sandbox.env`, which is ignored by Git.

## Script Options

```text
--project-id PROJECT_ID       Required Google Cloud Sandbox project ID.
--member-email EMAIL          Google user for Grafana BigQuery OAuth and Trace Explorer.
--build-mode auto|docker|cloud-build
--platform linux/amd64
--reuse-secrets               Reuse passwords from the previous .helix-sandbox.env.
--keep-local-state            Do not delete local Terraform cache/state first.
--skip-infra
--skip-build
--skip-deploy
--skip-observability
--skip-grafana-key
--skip-test
```

## App Access

The expected app URL format is:

```text
http://helix.<EXTERNAL_IP>.sslip.io
```

Print the current URL:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/get_user_portal_url.sh --project-id PROJECT_ID
```

Print credentials:

```bash
scripts/test_new_sandbox_apps.sh
```

Or read them from `.helix-sandbox.env`:

```bash
grep '^APP_LOGIN_' .helix-sandbox.env
```

## Grafana Cloud

The setup script creates:

```text
credentials/compute-default-service-account-key.json
```

Use these BigQuery datasource settings:

```text
Authentication type: Service Account Key
Service account key: contents of credentials/compute-default-service-account-key.json
Default project:     PROJECT_ID
Processing location: United States (US)
Service endpoint:    empty
```

Import this dashboard:

```text
observability/grafana/dashboards/helix-gke-observability.json
```

## Rerun Specific Phases

Recreate local config:

```bash
scripts/set_sandbox_project.sh --project-id PROJECT_ID
```

Apply infrastructure:

```bash
scripts/apply_new_sandbox_infra.sh --project-id PROJECT_ID
```

Configure Cloud Trace:

```bash
scripts/configure_cloud_trace.sh \
  --project-id PROJECT_ID \
  --viewer-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL
```

Build images:

```bash
scripts/build_new_sandbox_images.sh --mode docker
```

Deploy apps:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/deploy_new_sandbox_apps.sh
```

Test apps:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/test_new_sandbox_apps.sh
```

## Local Cleanup

The one-command setup cleans local Terraform state pointers by default. To clean manually:

```bash
rm -rf \
  iac/terraform/bootstrap/state-bucket/.terraform \
  iac/terraform/bootstrap/state-bucket/.terraform.lock.hcl \
  iac/terraform/bootstrap/state-bucket/terraform.tfstate \
  iac/terraform/bootstrap/state-bucket/terraform.tfstate.* \
  iac/terraform/bootstrap/state-bucket/terraform.tfvars \
  iac/terraform/environments/sandbox/.terraform \
  iac/terraform/environments/sandbox/.terraform.lock.hcl \
  iac/terraform/environments/sandbox/backend.hcl \
  iac/terraform/environments/sandbox/terraform.tfvars
```

This removes only local Terraform cache, config, and state pointers. It does not delete cloud resources in the old Google Cloud Sandbox project.

## Google Cloud Sandbox Constraints

- Project IAM policy updates can be restricted.
- Cloud Build can be restricted.
- Service account key creation can be restricted.
- GKE node quota is usually small.

The default workflow uses local Docker builds, minimal GKE node capacity, Workload Identity impersonation, and the Compute Engine default service account key for Grafana BigQuery to stay compatible with these constraints.
