#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .helix-sandbox.env ]]; then
  echo "Missing .helix-sandbox.env. Run scripts/set_sandbox_project.sh first." >&2
  exit 1
fi

set_env_var() {
  local key="$1"
  local value="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  grep -v "^${key}=" .helix-sandbox.env > "$tmp_file" || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
  mv "$tmp_file" .helix-sandbox.env
}

# shellcheck disable=SC1091
source .helix-sandbox.env

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/deploy_apps_to_gke.sh \
  --project-id "$PROJECT_ID" \
  --image-tag "$IMAGE_TAG" \
  --mysql-image-tag "$MYSQL_IMAGE_TAG" \
  --mysql-password "$MYSQL_PASSWORD" \
  --mysql-root-password "$MYSQL_ROOT_PASSWORD" \
  --flask-secret-key "$FLASK_SECRET_KEY"

EXTERNAL_IP="$(
  gcloud compute addresses describe "${NAME_PREFIX}-${ENVIRONMENT}-external-https-ip" \
    --global \
    --project "$PROJECT_ID" \
    --format='value(address)'
)"

HOST="helix.${EXTERNAL_IP}.sslip.io"

PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/expose_user_portal_external.sh \
  --project-id "$PROJECT_ID" \
  --host "$HOST"

set_env_var EXTERNAL_IP "$EXTERNAL_IP"
set_env_var APP_URL "http://${HOST}"

echo "App URL: http://${HOST}"
