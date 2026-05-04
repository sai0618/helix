#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Bootstrap and apply the Helix sandbox Terraform stack.

This script:
  1. Creates or updates the GCS Terraform state bucket.
  2. Writes sandbox terraform.tfvars and backend.hcl.
  3. Initializes the sandbox backend.
  4. Applies modules in order through Artifact Registry.
  5. Runs a final full terraform apply and plan check.

Usage:
  iac/terraform/scripts/apply_sandbox.sh --project-id PROJECT_ID [options]

Options:
  --project-id PROJECT_ID       Existing GCP project ID. Required.
  --bucket-name BUCKET_NAME     GCS state bucket name. Defaults to PROJECT_ID-helix-tfstate.
  --primary-region REGION      Primary region. Defaults to us-central1.
  --secondary-region REGION    Secondary region. Defaults to us-east1.
  --environment NAME           Environment name. Defaults to sandbox.
  --name-prefix PREFIX         Resource name prefix. Defaults to helix.
  --migrate-state              Use terraform init -migrate-state instead of -reconfigure.
  --help                       Show this help.

Example:
  iac/terraform/scripts/apply_sandbox.sh \
    --project-id PROJECT_ID
EOF
}

project_id=""
bucket_name=""
primary_region="us-central1"
secondary_region="us-east1"
environment="sandbox"
name_prefix="helix"
init_mode="-reconfigure"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      project_id="${2:-}"
      shift 2
      ;;
    --bucket-name)
      bucket_name="${2:-}"
      shift 2
      ;;
    --primary-region)
      primary_region="${2:-}"
      shift 2
      ;;
    --secondary-region)
      secondary_region="${2:-}"
      shift 2
      ;;
    --environment)
      environment="${2:-}"
      shift 2
      ;;
    --name-prefix)
      name_prefix="${2:-}"
      shift 2
      ;;
    --migrate-state)
      init_mode="-migrate-state"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$project_id" ]]; then
  echo "Missing required argument: --project-id" >&2
  usage
  exit 2
fi

if [[ -z "$bucket_name" ]]; then
  bucket_name="${project_id}-${name_prefix}-tfstate"
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is not installed or not on PATH." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_root="$(cd "${script_dir}/.." && pwd)"
bootstrap_dir="${terraform_root}/bootstrap/state-bucket"
sandbox_dir="${terraform_root}/environments/sandbox"

echo "Project ID:       ${project_id}"
echo "State bucket:     ${bucket_name}"
echo "Primary region:   ${primary_region}"
echo "Secondary region: ${secondary_region}"
echo "Environment:      ${environment}"
echo "Name prefix:      ${name_prefix}"
echo

if command -v gcloud >/dev/null 2>&1; then
  active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
  if [[ -n "${active_account}" ]]; then
    echo "Active gcloud account: ${active_account}"
  else
    echo "No active gcloud account found. Terraform must still have credentials through ADC or GOOGLE_APPLICATION_CREDENTIALS."
  fi
else
  echo "gcloud is not on PATH. Terraform must have credentials through ADC or GOOGLE_APPLICATION_CREDENTIALS."
fi
echo

echo "Writing bootstrap terraform.tfvars..."
cat >"${bootstrap_dir}/terraform.tfvars" <<EOF
project_id  = "${project_id}"
region      = "${primary_region}"
bucket_name = "${bucket_name}"
EOF

bootstrap_state="${bootstrap_dir}/terraform.tfstate"
if [[ -f "${bootstrap_state}" ]] && ! grep -q "${bucket_name}" "${bootstrap_state}"; then
  backup_path="${bootstrap_state}.backup.$(date +%Y%m%d%H%M%S)"
  echo "Existing bootstrap state appears to reference a different state bucket."
  echo "Moving ${bootstrap_state} to ${backup_path}"
  mv "${bootstrap_state}" "${backup_path}"
fi

echo "Bootstrapping GCS state bucket..."
terraform -chdir="${bootstrap_dir}" init
terraform -chdir="${bootstrap_dir}" fmt
terraform -chdir="${bootstrap_dir}" validate
if ! terraform -chdir="${bootstrap_dir}" apply -auto-approve; then
  cat <<EOF >&2

Failed to bootstrap the Terraform state bucket.

If the error mentions UREQ_TOS_NOT_ACCEPTED or "terms of service", open the
Google Cloud Console for this Google Cloud Sandbox project and accept the Google Cloud terms:

  https://console.developers.google.com/terms/cloud

Then rerun:

  iac/terraform/scripts/apply_sandbox.sh --project-id ${project_id}

EOF
  exit 1
fi

echo "Writing sandbox terraform.tfvars..."
cat >"${sandbox_dir}/terraform.tfvars" <<EOF
project_id = "${project_id}"

environment      = "${environment}"
name_prefix      = "${name_prefix}"
primary_region   = "${primary_region}"
secondary_region = "${secondary_region}"

admin_source_ranges = []

# Google Cloud Sandbox projects commonly allow service account creation but deny project IAM policy updates.
create_project_iam_bindings = false
EOF

echo "Writing sandbox backend.hcl..."
cat >"${sandbox_dir}/backend.hcl" <<EOF
bucket = "${bucket_name}"
prefix = "${name_prefix}/${environment}"
EOF

echo "Initializing sandbox backend (${init_mode})..."
terraform -chdir="${sandbox_dir}" init -backend-config=backend.hcl "${init_mode}"

echo "Formatting and validating sandbox Terraform..."
terraform -chdir="${sandbox_dir}" fmt -recursive ../..
terraform -chdir="${sandbox_dir}" validate

targets=(
  "module.project_services"
  "module.iam"
  "module.network"
  "module.private_service_access"
  "module.cloud_nat"
  "module.firewall"
  "module.artifact_registry"
)

for target in "${targets[@]}"; do
  echo
  echo "Applying ${target}..."
  terraform -chdir="${sandbox_dir}" apply -auto-approve -target="${target}"
done

echo
echo "Running final full apply to reconcile outputs and dependencies..."
terraform -chdir="${sandbox_dir}" apply -auto-approve

echo
echo "Running final plan check..."
terraform -chdir="${sandbox_dir}" plan

echo
echo "Sandbox Terraform apply complete."
