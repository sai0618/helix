# Helix Terraform

Terraform provisions the Helix infrastructure in an existing Google Cloud Sandbox project. The project itself is not created or destroyed by this code.

Use [Project Implementation](../../docs/project-implementation.md) for the full setup flow. This README is a quick Terraform reference.

## Layout

```text
bootstrap/state-bucket/          GCS bucket used for Terraform remote state
environments/sandbox/            Sandbox root module
modules/project-services/        Required Google Cloud APIs
modules/iam/                     Service accounts and optional project IAM
modules/network/                 VPC, subnets, and secondary ranges
modules/private-service-access/  Service Networking private access
modules/cloud-nat/               Cloud Router and Cloud NAT
modules/firewall/                Baseline firewall rules
modules/artifact-registry/       Docker and Helm repositories
modules/gke-cluster/             Minimal GKE clusters
modules/secret-manager/          Application secrets
modules/ingress-foundation/      Static ingress IPs
modules/observability/           Logging sinks and BigQuery datasets
```

## Resource Sequence

The automated setup applies Terraform in this sequence:

1. Bootstrap GCS state bucket.
2. Enable project services.
3. Create service accounts and optional IAM bindings.
4. Create VPC, subnets, and secondary ranges.
5. Create Private Service Access.
6. Create Cloud NAT.
7. Create firewall rules.
8. Create Artifact Registry repositories.
9. Create GKE clusters.
10. Create Secret Manager secrets.
11. Reserve ingress IPs.
12. Create observability BigQuery datasets and Cloud Logging sinks.

## Recommended Usage

Run from the repository root:

```bash
./setup_new_sandbox.sh \
  --project-id PROJECT_ID \
  --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL \
  --build-mode docker
```

For infrastructure only:

```bash
scripts/apply_new_sandbox_infra.sh --project-id PROJECT_ID
```

## Manual Terraform Commands

Bootstrap state:

```bash
cd iac/terraform/bootstrap/state-bucket
terraform init
terraform apply
```

Apply the sandbox environment:

```bash
cd iac/terraform/environments/sandbox
terraform init -backend-config=backend.hcl -reconfigure
terraform fmt -recursive ../..
terraform validate
terraform apply
```

## Sandbox Notes

- Keep `create_project_iam_bindings = false` when project IAM policy updates are restricted.
- Leave `gke_node_service_account_email` empty to use the Compute Engine default service account.
- Keep `admin_source_ranges = []` unless you explicitly need CIDR-restricted admin access.
- Use minimal GKE capacity for sandbox quotas.
- Generated files such as `terraform.tfvars`, `backend.hcl`, local state files, and credentials must stay out of Git.
