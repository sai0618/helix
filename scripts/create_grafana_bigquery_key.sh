#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
OUTPUT_FILE="credentials/compute-default-service-account-key.json"
FORCE="false"

usage() {
  cat <<USAGE
Usage:
  scripts/create_grafana_bigquery_key.sh --project-id PROJECT_ID [options]

Creates a local JSON key for the Compute Engine default service account.
Use this key for the Grafana Cloud BigQuery datasource in Google Cloud Sandbox projects
where custom service account IAM grants are blocked.

Options:
  --project-id PROJECT_ID   Existing GCP project ID. Required.
  --output-file PATH        Default: credentials/compute-default-service-account-key.json.
  --force                   Replace the local key file if it already exists.
  -h, --help                Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --force)
      FORCE="true"
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

for required_command in gcloud bq; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

PROJECT_NUMBER="$(
  gcloud projects describe "$PROJECT_ID" \
    --format='value(projectNumber)'
)"

if [[ -z "$PROJECT_NUMBER" ]]; then
  echo "Could not resolve project number for ${PROJECT_ID}" >&2
  exit 1
fi

SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT" --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "Compute Engine default service account not found: ${SERVICE_ACCOUNT}" >&2
  echo "Run infrastructure setup first so Compute Engine API/default service account exists." >&2
  exit 1
fi

if [[ -d iac/terraform/environments/sandbox ]]; then
  echo "Applying BigQuery log dataset viewer bindings for Grafana..."
  terraform -chdir=iac/terraform/environments/sandbox apply \
    -target='module.observability_log_exports["main"].google_bigquery_dataset_iam_member.dataset_viewers' \
    -auto-approve
  echo
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [[ -f "$OUTPUT_FILE" ]]; then
  if [[ "$FORCE" != "true" ]]; then
    echo "Key file already exists: ${OUTPUT_FILE}" >&2
    echo "Pass --force to replace the local file for a new Google Cloud Sandbox project." >&2
    exit 1
  fi
  rm -f "$OUTPUT_FILE"
fi

echo "Project:         ${PROJECT_ID}"
echo "Service account: ${SERVICE_ACCOUNT}"
echo "Output file:     ${OUTPUT_FILE}"

gcloud iam service-accounts keys create "$OUTPUT_FILE" \
  --iam-account "$SERVICE_ACCOUNT" \
  --project "$PROJECT_ID"

echo
echo "Testing BigQuery job creation with generated key..."
CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$OUTPUT_FILE" \
  bq --project_id="$PROJECT_ID" query --use_legacy_sql=false 'SELECT 1 AS test'

echo
echo "Testing BigQuery app log dataset read access with generated key..."
CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$OUTPUT_FILE" \
  bq --project_id="$PROJECT_ID" query --use_legacy_sql=false \
  "SELECT COUNT(1) AS row_count FROM \`${PROJECT_ID}.helix_sandbox_user_portal_app_logs.stdout\`"

echo
echo "Grafana BigQuery service account key is ready: ${OUTPUT_FILE}"
