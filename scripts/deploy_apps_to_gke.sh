#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
REGION="us-central1"
REPOSITORY="helix-sandbox-docker"
IMAGE_NAME="user-portal"
IMAGE_TAG=""
MYSQL_IMAGE_NAME="user-data"
MYSQL_IMAGE_TAG=""
NAMESPACE="helix"
MYSQL_RELEASE="helix-mysql"
PORTAL_RELEASE="helix-user-portal"
PRIMARY_CONTEXT=""
SECONDARY_CONTEXT=""
MYSQL_PASSWORD=""
MYSQL_ROOT_PASSWORD=""
FLASK_SECRET_KEY=""
SKIP_SECONDARY="false"

usage() {
  cat <<USAGE
Usage:
  scripts/deploy_apps_to_gke.sh --project-id PROJECT_ID --image-tag TAG [options]

Options:
  --project-id PROJECT_ID       GCP project ID. Required.
  --image-tag TAG               User portal image tag, for example v1. Required.
  --region REGION               Artifact Registry region. Default: us-central1.
  --repository NAME             Artifact Registry Docker repo. Default: helix-sandbox-docker.
  --image-name NAME             Image name. Default: user-portal.
  --namespace NAME              Kubernetes namespace. Default: helix.
  --mysql-image-name NAME       MySQL image name. Default: user-data.
  --mysql-image-tag TAG         MySQL image tag. Default: same as --image-tag.
  --mysql-password VALUE        MySQL app password. Default: generated.
  --mysql-root-password VALUE   MySQL root password. Default: generated.
  --flask-secret-key VALUE      Flask secret key. Default: generated.
  --primary-context NAME        Primary kube context. Default: derived from project ID.
  --secondary-context NAME      Secondary kube context. Default: derived from project ID.
  --skip-secondary             Deploy only to the primary cluster.
  -h, --help                    Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --image-tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --repository)
      REPOSITORY="$2"
      shift 2
      ;;
    --image-name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --mysql-image-name)
      MYSQL_IMAGE_NAME="$2"
      shift 2
      ;;
    --mysql-image-tag)
      MYSQL_IMAGE_TAG="$2"
      shift 2
      ;;
    --mysql-password)
      MYSQL_PASSWORD="$2"
      shift 2
      ;;
    --mysql-root-password)
      MYSQL_ROOT_PASSWORD="$2"
      shift 2
      ;;
    --flask-secret-key)
      FLASK_SECRET_KEY="$2"
      shift 2
      ;;
    --primary-context)
      PRIMARY_CONTEXT="$2"
      shift 2
      ;;
    --secondary-context)
      SECONDARY_CONTEXT="$2"
      shift 2
      ;;
    --skip-secondary)
      SKIP_SECONDARY="true"
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

if [[ -z "$PROJECT_ID" || -z "$IMAGE_TAG" ]]; then
  echo "--project-id and --image-tag are required" >&2
  usage >&2
  exit 1
fi

if [[ -z "$PRIMARY_CONTEXT" ]]; then
  PRIMARY_CONTEXT="gke_${PROJECT_ID}_us-central1-a_helix-sandbox-primary-gke"
fi

if [[ -z "$SECONDARY_CONTEXT" ]]; then
  SECONDARY_CONTEXT="gke_${PROJECT_ID}_us-east1-b_helix-sandbox-secondary-gke"
fi

if [[ -z "$MYSQL_IMAGE_TAG" ]]; then
  MYSQL_IMAGE_TAG="$IMAGE_TAG"
fi

PROJECT_NUMBER="$(
  gcloud projects describe "$PROJECT_ID" \
    --format='value(projectNumber)'
)"
COMPUTE_DEFAULT_SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

if [[ -z "$MYSQL_PASSWORD" ]]; then
  MYSQL_PASSWORD="$(openssl rand -base64 24)"
fi

if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
  MYSQL_ROOT_PASSWORD="$(openssl rand -base64 24)"
fi

if [[ -z "$FLASK_SECRET_KEY" ]]; then
  FLASK_SECRET_KEY="$(openssl rand -base64 32)"
fi

IMAGE_REPOSITORY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}"
MYSQL_IMAGE_REPOSITORY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${MYSQL_IMAGE_NAME}"

deploy_context() {
  local context="$1"
  echo "Deploying to context: $context"

  helm upgrade --install "$MYSQL_RELEASE" ./helm-charts/mysql \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --kube-context "$context" \
    --set auth.rootPassword="$MYSQL_ROOT_PASSWORD" \
    --set auth.password="$MYSQL_PASSWORD" \
    --set image.repository="$MYSQL_IMAGE_REPOSITORY" \
    --set image.tag="$MYSQL_IMAGE_TAG" \
    --set resources.requests.cpu=10m \
    --set resources.requests.memory=128Mi \
    --set resources.limits.cpu=200m \
    --set resources.limits.memory=512Mi \
    --wait \
    --timeout 10m

  helm upgrade --install "$PORTAL_RELEASE" ./helm-charts/user-portal \
    --namespace "$NAMESPACE" \
    --kube-context "$context" \
    --set image.repository="$IMAGE_REPOSITORY" \
    --set image.tag="$IMAGE_TAG" \
    --set replicaCount=1 \
    --set config.flaskSecretKey="$FLASK_SECRET_KEY" \
    --set tracing.enabled=true \
    --set tracing.projectId="$PROJECT_ID" \
    --set tracing.sampleRate=1.0 \
    --set-string serviceAccount.annotations."iam\\.gke\\.io/gcp-service-account"="$COMPUTE_DEFAULT_SERVICE_ACCOUNT" \
    --set secretManager.enabled=true \
    --set secretManager.projectId="$PROJECT_ID" \
    --set secretManager.appLoginSecretName=helix-sandbox-app-login-credentials \
    --set secretManager.mysqlSecretName=helix-sandbox-mysql-credentials \
    --set resources.requests.cpu=25m \
    --set resources.requests.memory=96Mi \
    --set resources.limits.cpu=200m \
    --set resources.limits.memory=256Mi \
    --wait \
    --timeout 10m
}

deploy_context "$PRIMARY_CONTEXT"

if [[ "$SKIP_SECONDARY" != "true" ]]; then
  deploy_context "$SECONDARY_CONTEXT"
fi

echo
echo "Deployed ${IMAGE_REPOSITORY}:${IMAGE_TAG} to:"
echo "  $PRIMARY_CONTEXT"
if [[ "$SKIP_SECONDARY" != "true" ]]; then
  echo "  $SECONDARY_CONTEXT"
fi
echo
echo "To access the UI locally:"
echo "  PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:\$PATH USE_GKE_GCLOUD_AUTH_PLUGIN=True scripts/open_user_portal.sh --project-id $PROJECT_ID"
