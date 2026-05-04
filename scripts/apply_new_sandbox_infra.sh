#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""

usage() {
  cat <<USAGE
Usage:
  scripts/apply_new_sandbox_infra.sh --project-id PROJECT_ID

Creates base Terraform resources, GKE clusters, Secret Manager app secrets, and ingress static IPs.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_ID" ]]; then
  echo "--project-id is required" >&2
  usage >&2
  exit 1
fi

scripts/set_sandbox_project.sh --project-id "$PROJECT_ID" --reuse-secrets

# shellcheck disable=SC1091
source .helix-sandbox.env

iac/terraform/scripts/apply_sandbox.sh \
  --project-id "$PROJECT_ID" \
  --bucket-name "$STATE_BUCKET" \
  --primary-region "$PRIMARY_REGION" \
  --secondary-region "$SECONDARY_REGION" \
  --environment "$ENVIRONMENT" \
  --name-prefix "$NAME_PREFIX"

# apply_sandbox.sh writes a base tfvars file; rewrite the full app platform flags.
scripts/set_sandbox_project.sh --project-id "$PROJECT_ID" --reuse-secrets

SANDBOX_DIR="iac/terraform/environments/sandbox"

terraform -chdir="$SANDBOX_DIR" init -backend-config=backend.hcl -reconfigure
terraform -chdir="$SANDBOX_DIR" fmt -recursive ../..
terraform -chdir="$SANDBOX_DIR" validate

terraform -chdir="$SANDBOX_DIR" apply -auto-approve -target=module.gke_clusters
terraform -chdir="$SANDBOX_DIR" apply -auto-approve -target=module.application_secrets
terraform -chdir="$SANDBOX_DIR" apply -auto-approve -target=module.ingress_foundation
terraform -chdir="$SANDBOX_DIR" apply -auto-approve

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
gcloud container clusters get-credentials "${NAME_PREFIX}-${ENVIRONMENT}-primary-gke" \
  --zone "$PRIMARY_ZONE" \
  --project "$PROJECT_ID"

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
gcloud container clusters get-credentials "${NAME_PREFIX}-${ENVIRONMENT}-secondary-gke" \
  --zone "$SECONDARY_ZONE" \
  --project "$PROJECT_ID"

echo "Infrastructure is ready for project ${PROJECT_ID}."
