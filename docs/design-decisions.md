# Design Decisions

## Existing Project

Use an existing Google Cloud Sandbox project. The repo provisions resources inside the project and does not manage project lifecycle.

## Minimal GKE

Use small zonal GKE clusters and low node capacity to fit sandbox quota. The design still keeps primary and secondary clusters for resiliency practice.

## Terraform First

Terraform owns cloud infrastructure: APIs, networking, IAM scaffolding, GKE, Artifact Registry, secrets, ingress IPs, and log exports.

## Helm For Workloads

Helm owns Kubernetes resources. This keeps app deployment separate from cloud infrastructure.

## Two Deployable Apps

The UI and API are merged into `user-portal`. MySQL initialization lives in `user-data`.

## MySQL StatefulSet

MySQL runs in GKE for learning StatefulSet, PVC, service discovery, and initialization patterns. Cloud SQL remains available in Terraform for later managed database practice.

## Local Docker Builds

Default image builds use local Docker because Cloud Build permissions can be restricted in Google Cloud Sandbox projects.

## Secret Manager

Application login and MySQL credentials are stored in Secret Manager. The user portal mounts them through the GKE Secret Manager CSI driver.

## Workload Identity

The user portal Kubernetes service account impersonates the Compute Engine default service account. This avoids Cloud Trace permission failures when raw workload identity principals cannot write traces.

## Structured Logs

The app writes JSON logs to stdout. Cloud Logging collects them without sidecars, and BigQuery log sinks make them queryable by Grafana.

## BigQuery For Grafana Logs

Grafana golden-signal panels use BigQuery because exported structured logs are easy to group by API, status, and latency.

## Cloud Trace With OpenTelemetry

The Flask app uses OpenTelemetry for request, database, and CRUD spans. Cloud Trace is the trace backend.

## External Ingress

The app is exposed with GKE Ingress and an `sslip.io` hostname so browser access does not require port forwarding or DNS ownership.
