# Helix

Helix is a learning project for building production-style Google Cloud infrastructure with Terraform, GKE, Helm, and Google Cloud observability. The goal is to practice the core SRE and DevOps workflows behind networking, resilient Kubernetes platforms, service deployment, and operational visibility.

## Scope

This project targets an existing Google Cloud project and provisions a small application platform made of two deployable workloads:

- **User portal**: Public-facing Flask/Jinja2 web app with REST API routes in the same service.
- **User data**: MySQL database workload deployed as a StatefulSet with initialization data.

Infrastructure is provisioned with Terraform, workloads are deployed with Helm charts, and the platform is observed through Google Cloud's logging, metrics, tracing, alerting, and dashboarding capabilities.

## Baseline Apps

The initial application baseline lives under `apps/`:

- `user-portal`: Flask and Jinja2 app that serves the user registration UI and REST API.
- `user-data`: MySQL initialization SQL and MySQL seed image.

The previous standalone `user-api` service has been merged into `user-portal`. MySQL is the backing database for the deployed baseline.

## Implementation Guide

Use [Project Implementation](docs/project-implementation.md) as the canonical setup guide. It covers the Terraform resource sequence, image build flow, Helm deployment, observability, traces, Grafana, app access, and validation.

Supporting docs:

- [Architecture](docs/architecture.md)
- [BigQuery Schema And Grafana Queries](docs/bigquery-grafana.md)
- [Design Decisions](docs/design-decisions.md)

For a new Google Cloud Sandbox project, the normal workflow is:

```bash
./setup_new_sandbox.sh \
  --project-id PROJECT_ID \
  --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL \
  --build-mode docker
```

## Repository Layout

```text
.
├── README.md
├── setup_new_sandbox.sh
├── scripts/
├── iac/
│   └── terraform/
│       ├── environments/
│       └── modules/
├── helm-charts/
│   ├── user-portal/
│   └── mysql/
├── apps/
│   ├── user-portal/
│   └── user-data/
├── observability/
│   ├── bigquery/
│   └── grafana/
└── docs/
    ├── architecture.md
    ├── bigquery-grafana.md
    ├── design-decisions.md
    ├── project-implementation.md
    ├── project-requirements.md
    ├── cloud-trace-otel.md
    └── grafana-cloud-observability.md
```

## Learning Milestones

1. Create Terraform remote state and enable required Google Cloud APIs.
2. Build the VPC, subnets, firewall rules, NAT, and private GKE networking.
3. Provision minimal primary and secondary GKE clusters for the sandbox.
4. Configure Artifact Registry and Workload Identity.
5. Create Helm charts for the user portal and MySQL database services.
6. Deploy the services and expose the user portal through external GKE Ingress.
7. Add health checks, autoscaling, disruption budgets, and resource limits.
8. Add logging, Cloud Logging sinks, BigQuery log exports, metrics, tracing, Grafana dashboards, and alerts.
9. Practice failure scenarios: pod failure, node drain, zone disruption, database restore, and rollback.
10. Document runbooks and operational checks.
