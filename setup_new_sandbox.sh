#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
MEMBER_EMAIL=""
BUILD_MODE="auto"
PLATFORM="linux/amd64"
REUSE_SECRETS="false"
CLEAN_LOCAL_STATE="true"
SKIP_INFRA="false"
SKIP_BUILD="false"
SKIP_DEPLOY="false"
SKIP_OBSERVABILITY="false"
SKIP_GRAFANA_KEY="false"
SKIP_TEST="false"

usage() {
  cat <<USAGE
Usage:
  ./setup_new_sandbox.sh --project-id PROJECT_ID [options]

End-to-end Google Cloud Sandbox setup:
  1. Selects the GCP project.
  2. Cleans local Terraform cache/state files for the previous Google Cloud Sandbox.
  3. Writes local Google Cloud Sandbox config and Terraform backend/tfvars files.
  4. Applies Terraform infrastructure.
  5. Configures Cloud Trace API, Workload Identity impersonation, and Grafana BigQuery OAuth.
  6. Creates a Grafana Cloud BigQuery service account key.
  7. Builds and pushes app images.
  8. Deploys Helm releases to GKE.
  9. Tests the deployed application.

Options:
  --project-id PROJECT_ID       Google Cloud Sandbox project ID. Required.
  --member-email EMAIL         Google user for Grafana BigQuery OAuth and Trace Explorer.
                                Default: active gcloud account.
  --build-mode auto|docker|cloud-build
                                Image build mode. Default: auto.
  --platform PLATFORM          Docker build platform. Default: linux/amd64.
  --reuse-secrets              Reuse passwords from existing .helix-sandbox.env.
  --keep-local-state           Do not delete local Terraform cache/state files first.
  --skip-infra                 Skip Terraform infrastructure setup.
  --skip-build                 Skip image build and push.
  --skip-deploy                Skip Helm deployment and ingress exposure.
  --skip-observability         Skip Cloud Trace and Grafana BigQuery OAuth helper scripts.
  --skip-grafana-key           Skip Grafana BigQuery service account key creation.
  --skip-test                  Skip smoke tests.
  -h, --help                   Show this help.

Examples:
  ./setup_new_sandbox.sh --project-id PROJECT_ID

  ./setup_new_sandbox.sh \\
    --project-id PROJECT_ID \\
    --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL \\
    --build-mode docker
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --member-email)
      MEMBER_EMAIL="$2"
      shift 2
      ;;
    --build-mode)
      BUILD_MODE="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --reuse-secrets)
      REUSE_SECRETS="true"
      shift
      ;;
    --keep-local-state)
      CLEAN_LOCAL_STATE="false"
      shift
      ;;
    --skip-infra)
      SKIP_INFRA="true"
      shift
      ;;
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    --skip-deploy)
      SKIP_DEPLOY="true"
      shift
      ;;
    --skip-observability)
      SKIP_OBSERVABILITY="true"
      shift
      ;;
    --skip-grafana-key)
      SKIP_GRAFANA_KEY="true"
      shift
      ;;
    --skip-test)
      SKIP_TEST="true"
      shift
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

case "$BUILD_MODE" in
  auto|docker|cloud-build) ;;
  *)
    echo "--build-mode must be auto, docker, or cloud-build" >&2
    exit 1
    ;;
esac

required_commands=(gcloud terraform kubectl helm bq curl openssl)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

if [[ -z "$MEMBER_EMAIL" ]]; then
  MEMBER_EMAIL="$(
    gcloud auth list \
      --filter=status:ACTIVE \
      --format='value(account)'
  )"
fi

if [[ -z "$MEMBER_EMAIL" ]]; then
  echo "No active gcloud account found. Run: gcloud auth login" >&2
  exit 1
fi

run_step() {
  local label="$1"
  shift
  echo
  echo "==> ${label}"
  "$@"
}

clean_local_state() {
  echo "Removing local Terraform cache/state files for previous Google Cloud Sandboxes..."
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
}

write_sandbox_config() {
  local args=(--project-id "$PROJECT_ID")
  if [[ "$REUSE_SECRETS" == "true" ]]; then
    args+=(--reuse-secrets)
  fi
  scripts/set_sandbox_project.sh "${args[@]}"
}

apply_infra() {
  scripts/apply_new_sandbox_infra.sh --project-id "$PROJECT_ID"
}

configure_observability() {
  scripts/configure_cloud_trace.sh \
    --project-id "$PROJECT_ID" \
    --viewer-email "$MEMBER_EMAIL"

  scripts/configure_grafana_bigquery_oauth.sh \
    --project-id "$PROJECT_ID" \
    --member-email "$MEMBER_EMAIL"
}

create_grafana_bigquery_key() {
  scripts/create_grafana_bigquery_key.sh \
    --project-id "$PROJECT_ID" \
    --force
}

build_images() {
  scripts/build_new_sandbox_images.sh \
    --mode "$BUILD_MODE" \
    --platform "$PLATFORM"
}

deploy_apps() {
  PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
  USE_GKE_GCLOUD_AUTH_PLUGIN=True \
  scripts/deploy_new_sandbox_apps.sh
}

test_apps() {
  local attempt
  local max_attempts=10

  for attempt in $(seq 1 "$max_attempts"); do
    echo "Smoke test attempt ${attempt}/${max_attempts}..."
    if PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
      USE_GKE_GCLOUD_AUTH_PLUGIN=True \
      scripts/test_new_sandbox_apps.sh; then
      return 0
    fi

    if [[ "$attempt" == "$max_attempts" ]]; then
      break
    fi

    echo "Smoke test failed. Waiting 30 seconds for GKE ingress/backend readiness..."
    sleep 30
  done

  echo "Smoke tests did not pass after ${max_attempts} attempts." >&2
  return 1
}

echo "Project:       $PROJECT_ID"
echo "Google user:   $MEMBER_EMAIL"
echo "Build mode:    $BUILD_MODE"
echo "Platform:      $PLATFORM"
echo "Clean state:   $CLEAN_LOCAL_STATE"
echo

run_step "Set active gcloud project" gcloud config set project "$PROJECT_ID"

if [[ "$CLEAN_LOCAL_STATE" == "true" ]]; then
  run_step "Clean local Terraform state/cache" clean_local_state
fi

run_step "Write sandbox config" write_sandbox_config

if [[ "$SKIP_INFRA" != "true" ]]; then
  run_step "Apply infrastructure" apply_infra
fi

if [[ "$SKIP_OBSERVABILITY" != "true" ]]; then
  run_step "Configure observability permissions and APIs" configure_observability
fi

if [[ "$SKIP_GRAFANA_KEY" != "true" ]]; then
  run_step "Create Grafana BigQuery service account key" create_grafana_bigquery_key
fi

if [[ "$SKIP_BUILD" != "true" ]]; then
  run_step "Build and push images" build_images
fi

if [[ "$SKIP_DEPLOY" != "true" ]]; then
  run_step "Deploy apps to GKE" deploy_apps
fi

if [[ "$SKIP_TEST" != "true" ]]; then
  run_step "Test apps" test_apps
fi

echo
echo "Sandbox setup finished."
if [[ -f .helix-sandbox.env ]]; then
  # shellcheck disable=SC1091
  source .helix-sandbox.env
  echo "App URL: ${APP_URL:-not available yet}"
  echo "App username: ${APP_LOGIN_USERNAME:-admin}"
  echo "App password is stored in .helix-sandbox.env"
fi
