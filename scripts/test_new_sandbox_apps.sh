#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .helix-sandbox.env ]]; then
  echo "Missing .helix-sandbox.env. Run scripts/set_sandbox_project.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source .helix-sandbox.env

PRIMARY_CONTEXT="gke_${PROJECT_ID}_${PRIMARY_ZONE}_${NAME_PREFIX}-${ENVIRONMENT}-primary-gke"
SECONDARY_CONTEXT="gke_${PROJECT_ID}_${SECONDARY_ZONE}_${NAME_PREFIX}-${ENVIRONMENT}-secondary-gke"

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
kubectl --context "$PRIMARY_CONTEXT" get pods,svc,ingress -n helix

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
kubectl --context "$SECONDARY_CONTEXT" get pods,svc -n helix

URL="${APP_URL:-}"
if [[ -z "$URL" ]]; then
  URL="$(
    PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
    USE_GKE_GCLOUD_AUTH_PLUGIN=True \
    scripts/get_user_portal_url.sh --project-id "$PROJECT_ID"
  )"
fi

echo "Testing ${URL}/healthz"
curl -fsS "${URL}/healthz"
echo
echo "Testing ${URL}"
curl -I --max-time 20 "$URL"

POD_NAME="$(
  PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
  USE_GKE_GCLOUD_AUTH_PLUGIN=True \
  kubectl --context "$PRIMARY_CONTEXT" \
    -n helix \
    get pods \
    -l app.kubernetes.io/name=user-portal \
    -o jsonpath='{.items[0].metadata.name}'
)"

echo
echo "Checking Cloud Trace workload identity for ${POD_NAME}"
TRACE_IDENTITY="$(
  PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
  USE_GKE_GCLOUD_AUTH_PLUGIN=True \
  kubectl --context "$PRIMARY_CONTEXT" \
    -n helix \
    exec "$POD_NAME" \
    -- python -c 'import urllib.request; print(urllib.request.urlopen(urllib.request.Request("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email", headers={"Metadata-Flavor":"Google"}), timeout=5).read().decode())'
)"
echo "Trace identity: ${TRACE_IDENTITY}"

echo "Checking recent Cloud Trace exporter errors"
if PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
  USE_GKE_GCLOUD_AUTH_PLUGIN=True \
  kubectl --context "$PRIMARY_CONTEXT" \
    -n helix \
    logs "$POD_NAME" \
    --since=10m | grep -E 'Error while writing to Cloud Trace|PermissionDenied|PERMISSION_DENIED'; then
  echo "Cloud Trace exporter errors were found in recent user-portal logs." >&2
  exit 1
fi

echo
echo "App URL: ${URL}"
echo "Username: ${APP_LOGIN_USERNAME}"
echo "Password: ${APP_LOGIN_PASSWORD}"
