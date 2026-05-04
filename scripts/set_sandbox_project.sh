#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
PRIMARY_REGION="us-central1"
SECONDARY_REGION="us-east1"
PRIMARY_ZONE="us-central1-a"
SECONDARY_ZONE="us-east1-b"
ENVIRONMENT="sandbox"
NAME_PREFIX="helix"
APP_LOGIN_USERNAME="admin"
REUSE_SECRETS="false"

usage() {
  cat <<USAGE
Usage:
  scripts/set_sandbox_project.sh --project-id PROJECT_ID [options]

Writes local sandbox config for a new Google Cloud Sandbox project:
  - .helix-sandbox.env
  - iac/terraform/bootstrap/state-bucket/terraform.tfvars
  - iac/terraform/environments/sandbox/terraform.tfvars
  - iac/terraform/environments/sandbox/backend.hcl

Options:
  --project-id PROJECT_ID       Existing GCP project ID. Required.
  --primary-region REGION      Default: us-central1.
  --secondary-region REGION    Default: us-east1.
  --primary-zone ZONE          Default: us-central1-a.
  --secondary-zone ZONE        Default: us-east1-b.
  --environment NAME           Default: sandbox.
  --name-prefix PREFIX         Default: helix.
  --app-login-username NAME    Default: admin.
  --reuse-secrets              Reuse existing passwords from .helix-sandbox.env if present.
  -h, --help                   Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --primary-region)
      PRIMARY_REGION="$2"
      shift 2
      ;;
    --secondary-region)
      SECONDARY_REGION="$2"
      shift 2
      ;;
    --primary-zone)
      PRIMARY_ZONE="$2"
      shift 2
      ;;
    --secondary-zone)
      SECONDARY_ZONE="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --name-prefix)
      NAME_PREFIX="$2"
      shift 2
      ;;
    --app-login-username)
      APP_LOGIN_USERNAME="$2"
      shift 2
      ;;
    --reuse-secrets)
      REUSE_SECRETS="true"
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

if [[ "$REUSE_SECRETS" == "true" && -f .helix-sandbox.env ]]; then
  # shellcheck disable=SC1091
  source .helix-sandbox.env
fi

STATE_BUCKET="${PROJECT_ID}-${NAME_PREFIX}-tfstate"
APP_LOGIN_PASSWORD="${APP_LOGIN_PASSWORD:-$(openssl rand -base64 24)}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(openssl rand -base64 24)}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(openssl rand -base64 24)}"
FLASK_SECRET_KEY="${FLASK_SECRET_KEY:-$(openssl rand -base64 32)}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
MYSQL_IMAGE_TAG="${MYSQL_IMAGE_TAG:-$IMAGE_TAG}"

PROJECT_NUMBER="$(
  gcloud projects describe "$PROJECT_ID" \
    --format='value(projectNumber)'
)"

SECRET_ACCESSOR_MEMBER="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/helix/sa/helix-user-portal"
COMPUTE_DEFAULT_SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
ACTIVE_GCLOUD_ACCOUNT="$(
  gcloud auth list \
    --filter=status:ACTIVE \
    --format='value(account)'
)"

cat > .helix-sandbox.env <<EOF
PROJECT_ID=${PROJECT_ID}
PROJECT_NUMBER=${PROJECT_NUMBER}
PRIMARY_REGION=${PRIMARY_REGION}
SECONDARY_REGION=${SECONDARY_REGION}
PRIMARY_ZONE=${PRIMARY_ZONE}
SECONDARY_ZONE=${SECONDARY_ZONE}
ENVIRONMENT=${ENVIRONMENT}
NAME_PREFIX=${NAME_PREFIX}
STATE_BUCKET=${STATE_BUCKET}
APP_LOGIN_USERNAME=${APP_LOGIN_USERNAME}
APP_LOGIN_PASSWORD=${APP_LOGIN_PASSWORD}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
FLASK_SECRET_KEY=${FLASK_SECRET_KEY}
IMAGE_TAG=${IMAGE_TAG}
MYSQL_IMAGE_TAG=${MYSQL_IMAGE_TAG}
SECRET_ACCESSOR_MEMBER=${SECRET_ACCESSOR_MEMBER}
COMPUTE_DEFAULT_SERVICE_ACCOUNT=${COMPUTE_DEFAULT_SERVICE_ACCOUNT}
EOF

cat > iac/terraform/bootstrap/state-bucket/terraform.tfvars <<EOF
project_id  = "${PROJECT_ID}"
region      = "${PRIMARY_REGION}"
bucket_name = "${STATE_BUCKET}"
EOF

cat > iac/terraform/environments/sandbox/backend.hcl <<EOF
bucket = "${STATE_BUCKET}"
prefix = "${NAME_PREFIX}/${ENVIRONMENT}"
EOF

cat > iac/terraform/environments/sandbox/terraform.tfvars <<EOF
project_id = "${PROJECT_ID}"

environment      = "${ENVIRONMENT}"
name_prefix      = "${NAME_PREFIX}"
primary_region   = "${PRIMARY_REGION}"
secondary_region = "${SECONDARY_REGION}"
primary_zone     = "${PRIMARY_ZONE}"
secondary_zone   = "${SECONDARY_ZONE}"

admin_source_ranges = []

create_project_iam_bindings = false

enable_gke_clusters             = true
enable_ingress_foundation       = true
enable_cloud_logging            = true
enable_cloud_monitoring         = true
enable_bigquery_log_sinks       = true
log_export_dataset_location     = "US"
enable_secret_manager_csi       = true
enable_secret_manager_secrets   = true
enable_cloud_sql                = false
enable_cloud_sql_import         = false
enable_fleet_registration       = false
enable_cloud_service_mesh       = false
enable_multi_cluster_ingress    = false

app_login_username = "${APP_LOGIN_USERNAME}"
app_login_password = "${APP_LOGIN_PASSWORD}"

mysql_credentials_username = "helix_app"
mysql_credentials_password = "${MYSQL_PASSWORD}"
mysql_credentials_database = "helix_users"
mysql_credentials_host     = "helix-mysql"
mysql_credentials_port     = "3306"

secret_accessor_members = [
  "${SECRET_ACCESSOR_MEMBER}",
  "serviceAccount:${COMPUTE_DEFAULT_SERVICE_ACCOUNT}"
]

log_export_viewer_members = [
  "user:${ACTIVE_GCLOUD_ACCOUNT}",
  "serviceAccount:${COMPUTE_DEFAULT_SERVICE_ACCOUNT}"
]
EOF

echo "Sandbox config written for project ${PROJECT_ID}."
echo "Local secret/config file: .helix-sandbox.env"
echo "Terraform state bucket: ${STATE_BUCKET}"
echo "App username: ${APP_LOGIN_USERNAME}"
echo "App password is stored in .helix-sandbox.env and will be written to Secret Manager by Terraform."
