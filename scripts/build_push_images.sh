#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
REGION="us-central1"
REPOSITORY="helix-sandbox-docker"
IMAGE_NAME="user-portal"
CONTEXT_DIR="apps/user-portal"
MODE="docker"
VERSION=""
PUSH_LATEST="true"
PLATFORM="linux/amd64"

usage() {
  cat <<USAGE
Usage:
  scripts/build_push_images.sh --project-id PROJECT_ID [options]

Options:
  --project-id PROJECT_ID    GCP project ID. Required.
  --region REGION            Artifact Registry region. Default: us-central1.
  --repository NAME          Artifact Registry Docker repo. Default: helix-sandbox-docker.
  --image-name NAME          Image name. Default: user-portal.
  --context-dir DIR          Docker build context. Default: apps/user-portal.
  --mode docker|cloud-build  Build locally with Docker or submit to Cloud Build. Default: docker.
  --platform PLATFORM        Container platform for Docker builds. Default: linux/amd64.
  --version TAG              Explicit image version tag. Default: next vN from Artifact Registry.
  --no-latest                Do not also tag/push latest.
  -h, --help                 Show this help.

Examples:
  scripts/build_push_images.sh --project-id PROJECT_ID
  scripts/build_push_images.sh --project-id PROJECT_ID --mode docker
  scripts/build_push_images.sh --project-id PROJECT_ID --version v3
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
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
    --context-dir)
      CONTEXT_DIR="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --no-latest)
      PUSH_LATEST="false"
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

if [[ "$MODE" != "docker" && "$MODE" != "cloud-build" ]]; then
  echo "--mode must be docker or cloud-build" >&2
  exit 1
fi

if [[ ! -d "$CONTEXT_DIR" ]]; then
  echo "Build context not found: $CONTEXT_DIR" >&2
  exit 1
fi

IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}"

next_version() {
  local latest_number
  latest_number="$(
    gcloud artifacts docker tags list "$IMAGE_URI" \
      --project "$PROJECT_ID" \
      --format='value(tag)' 2>/dev/null \
      | awk -F: '{print $NF}' \
      | grep -E '^v[0-9]+$' \
      | sed 's/^v//' \
      | sort -n \
      | tail -1
  )"

  if [[ -z "$latest_number" ]]; then
    echo "v1"
  else
    echo "v$((latest_number + 1))"
  fi
}

if [[ -z "$VERSION" ]]; then
  VERSION="$(next_version)"
fi

VERSION_IMAGE="${IMAGE_URI}:${VERSION}"
LATEST_IMAGE="${IMAGE_URI}:latest"

echo "Project:      $PROJECT_ID"
echo "Repository:   ${REGION}/${REPOSITORY}"
echo "Image:        $IMAGE_NAME"
echo "Version tag:  $VERSION"
echo "Platform:     $PLATFORM"
echo "Image URI:    $VERSION_IMAGE"

if [[ "$MODE" == "docker" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker CLI is not installed. Install Docker or rerun with --mode cloud-build." >&2
    exit 1
  fi

  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

  if [[ "$PUSH_LATEST" == "true" ]]; then
    docker buildx build \
      --platform "$PLATFORM" \
      -t "$VERSION_IMAGE" \
      -t "$LATEST_IMAGE" \
      --push \
      "$CONTEXT_DIR"
  else
    docker buildx build \
      --platform "$PLATFORM" \
      -t "$VERSION_IMAGE" \
      --push \
      "$CONTEXT_DIR"
  fi
else
  CONFIG_FILE="$(mktemp)"
  trap 'rm -f "$CONFIG_FILE"' EXIT

  if [[ "$PUSH_LATEST" == "true" ]]; then
    cat > "$CONFIG_FILE" <<EOF
steps:
  - name: gcr.io/cloud-builders/docker
    args:
      - build
      - -t
      - ${VERSION_IMAGE}
      - -t
      - ${LATEST_IMAGE}
      - .
images:
  - ${VERSION_IMAGE}
  - ${LATEST_IMAGE}
EOF
  else
    cat > "$CONFIG_FILE" <<EOF
steps:
  - name: gcr.io/cloud-builders/docker
    args:
      - build
      - -t
      - ${VERSION_IMAGE}
      - .
images:
  - ${VERSION_IMAGE}
EOF
  fi

  if ! gcloud builds submit "$CONTEXT_DIR" \
    --config "$CONFIG_FILE" \
    --project "$PROJECT_ID"; then
    cat <<EOF >&2

Cloud Build failed for project ${PROJECT_ID}.

Common Google Cloud Sandbox project causes:
  - The sandbox user cannot create Cloud Build builds.
  - The project IAM policy does not grant cloudbuild.builds.create.

Fallback:
  1. Install and start Docker Desktop.
  2. Rerun this command with --mode docker.

Example:
  scripts/build_push_images.sh --project-id ${PROJECT_ID} --mode docker --image-name ${IMAGE_NAME} --context-dir ${CONTEXT_DIR}

EOF
    exit 1
  fi
fi

echo
echo "Built and pushed: $VERSION_IMAGE"
if [[ "$PUSH_LATEST" == "true" ]]; then
  echo "Updated latest:   $LATEST_IMAGE"
fi
echo "$VERSION" > "/tmp/helix-${IMAGE_NAME}-image-version"
