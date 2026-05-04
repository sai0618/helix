#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
VIEWER_EMAIL=""
NAMESPACE="helix"
KSA_NAME="helix-user-portal"

usage() {
  cat <<USAGE
Usage:
  scripts/configure_cloud_trace.sh --project-id PROJECT_ID [options]

Enables Cloud Trace APIs and attempts to grant roles needed to view and write
traces. In Google Cloud Sandbox projects, project IAM grants may be blocked by policy.

Options:
  --project-id PROJECT_ID    GCP project ID. Required.
  --viewer-email EMAIL       Google user that should view Trace Explorer. Default: active gcloud account.
  --namespace NAME           Kubernetes namespace for the user-portal service account. Default: helix.
  --ksa-name NAME            Kubernetes service account name. Default: helix-user-portal.
  -h, --help                 Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --viewer-email)
      VIEWER_EMAIL="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --ksa-name)
      KSA_NAME="$2"
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

if [[ -z "$VIEWER_EMAIL" ]]; then
  VIEWER_EMAIL="$(
    gcloud auth list \
      --filter=status:ACTIVE \
      --format='value(account)'
  )"
fi

if [[ -z "$VIEWER_EMAIL" ]]; then
  echo "No active gcloud account found. Run: gcloud auth login" >&2
  exit 1
fi

PROJECT_NUMBER="$(
  gcloud projects describe "$PROJECT_ID" \
    --format='value(projectNumber)'
)"

DEFAULT_COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
WORKLOAD_IDENTITY_PRINCIPAL="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${NAMESPACE}/sa/${KSA_NAME}"
WORKLOAD_IDENTITY_MEMBER="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]"

echo "Project: $PROJECT_ID"
echo "Viewer user: $VIEWER_EMAIL"
echo "Default Compute Engine service account: $DEFAULT_COMPUTE_SA"
echo "Workload Identity principal: $WORKLOAD_IDENTITY_PRINCIPAL"
echo "Workload Identity member: $WORKLOAD_IDENTITY_MEMBER"
echo

echo "Enabling Cloud Trace API..."
gcloud services enable cloudtrace.googleapis.com \
  --project "$PROJECT_ID"

echo
echo "Enabled API check:"
gcloud services list \
  --enabled \
  --project "$PROJECT_ID" \
  --filter='name:cloudtrace.googleapis.com' \
  --format='table(config.name)'

grant_role() {
  local member="$1"
  local role="$2"
  echo
  echo "Attempting to grant ${role} to ${member}..."
  if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="$member" \
    --role="$role"; then
    echo "Granted ${role} to ${member}."
  else
    echo "Could not grant ${role} to ${member}."
    echo "If this is a Google Cloud Sandbox project, project IAM updates might be restricted."
  fi
}

grant_role "user:${VIEWER_EMAIL}" "roles/cloudtrace.user"
grant_role "serviceAccount:${DEFAULT_COMPUTE_SA}" "roles/cloudtrace.agent"
grant_role "$WORKLOAD_IDENTITY_PRINCIPAL" "roles/cloudtrace.agent"

echo
echo "Allowing ${NAMESPACE}/${KSA_NAME} to impersonate ${DEFAULT_COMPUTE_SA}..."
if gcloud iam service-accounts add-iam-policy-binding "$DEFAULT_COMPUTE_SA" \
  --project "$PROJECT_ID" \
  --member="$WORKLOAD_IDENTITY_MEMBER" \
  --role="roles/iam.workloadIdentityUser"; then
  echo "Granted Workload Identity impersonation."
else
  echo "Could not grant Workload Identity impersonation."
  echo "Cloud Trace export may fail unless the KSA principal has roles/cloudtrace.agent directly."
fi

echo
echo "Trace Explorer viewer check:"
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten='bindings[].members' \
  --filter="bindings.role:roles/cloudtrace.user AND bindings.members:user:${VIEWER_EMAIL}" \
  --format='table(bindings.role,bindings.members)' || true

echo
echo "Trace writer checks:"
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten='bindings[].members' \
  --filter="bindings.role:roles/cloudtrace.agent" \
  --format='table(bindings.role,bindings.members)' || true
