#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
MEMBER_EMAIL=""

usage() {
  cat <<USAGE
Usage:
  scripts/configure_grafana_bigquery_oauth.sh --project-id PROJECT_ID [options]

Enables the Google APIs required by the Grafana Cloud BigQuery datasource and
checks whether the selected Google user can create BigQuery jobs for Forward
OAuth Identity.

Options:
  --project-id PROJECT_ID    GCP project ID. Required.
  --member-email EMAIL       Google user email to grant/check. Default: active gcloud account.
  -h, --help                 Show this help.

Example:
  scripts/configure_grafana_bigquery_oauth.sh \\
    --project-id PROJECT_ID \\
    --member-email YOUR_GOOGLE_CLOUD_SANDBOX_EMAIL
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

echo "Project: $PROJECT_ID"
echo "Google user: $MEMBER_EMAIL"
echo

echo "Setting active gcloud project..."
gcloud config set project "$PROJECT_ID"

echo
echo "Enabling required APIs..."
gcloud services enable bigquery.googleapis.com cloudresourcemanager.googleapis.com \
  --project "$PROJECT_ID"

echo
echo "Enabled API check:"
gcloud services list \
  --enabled \
  --project "$PROJECT_ID" \
  --filter='name:(bigquery.googleapis.com OR cloudresourcemanager.googleapis.com)' \
  --format='table(config.name)'

echo
echo "Attempting to grant BigQuery Job User to user:${MEMBER_EMAIL}..."
if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:${MEMBER_EMAIL}" \
  --role="roles/bigquery.jobUser"; then
  echo "Granted roles/bigquery.jobUser to user:${MEMBER_EMAIL}."
else
  echo
  echo "Could not grant roles/bigquery.jobUser."
  echo "This is expected in many Google Cloud Sandbox projects because project IAM updates are restricted."
  echo "If 'Grant access' is disabled in the console, rely on the built-in Google Cloud Sandbox user permissions."
fi

echo
echo "Project IAM check for roles/bigquery.jobUser:"
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten='bindings[].members' \
  --filter="bindings.role:roles/bigquery.jobUser AND bindings.members:user:${MEMBER_EMAIL}" \
  --format='table(bindings.role,bindings.members)' || true

echo
echo "Verifying BigQuery job creation as the active gcloud user..."
if bq --project_id="$PROJECT_ID" query --use_legacy_sql=false 'SELECT 1 AS test'; then
  echo
  echo "BigQuery job creation works for the active Google user."
  echo "Use Grafana Cloud BigQuery with Forward OAuth Identity and log into Grafana with this Google account:"
  echo "  ${MEMBER_EMAIL}"
else
  echo
  echo "BigQuery job creation failed for the active Google user."
  echo "Grafana Forward OAuth Identity will not work until this user has bigquery.jobs.create."
  exit 1
fi
