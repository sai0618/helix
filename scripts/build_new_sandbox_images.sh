#!/usr/bin/env bash
set -euo pipefail

MODE="auto"
PLATFORM="linux/amd64"

usage() {
  cat <<USAGE
Usage:
  scripts/build_new_sandbox_images.sh [options]

Options:
  --mode auto|docker|cloud-build  Build mode. Default: auto.
  --platform PLATFORM             Docker build platform. Default: linux/amd64.
  -h, --help                      Show this help.

Mode behavior:
  auto        Uses local Docker when available; otherwise uses Cloud Build.
  docker      Builds locally and pushes to Artifact Registry.
  cloud-build Submits remote builds to Cloud Build.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
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

if [[ "$MODE" != "auto" && "$MODE" != "docker" && "$MODE" != "cloud-build" ]]; then
  echo "--mode must be auto, docker, or cloud-build" >&2
  exit 1
fi

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

if [[ "$MODE" == "auto" ]]; then
  if command -v docker >/dev/null 2>&1; then
    MODE="docker"
  else
    MODE="cloud-build"
  fi
fi

echo "Build mode: ${MODE}"
echo "Build platform: ${PLATFORM}"

scripts/build_push_images.sh \
  --project-id "$PROJECT_ID" \
  --mode "$MODE" \
  --image-name user-portal \
  --context-dir apps/user-portal \
  --platform "$PLATFORM"

IMAGE_TAG="$(cat /tmp/helix-user-portal-image-version)"

scripts/build_push_images.sh \
  --project-id "$PROJECT_ID" \
  --mode "$MODE" \
  --image-name user-data \
  --context-dir apps/user-data \
  --version "$IMAGE_TAG" \
  --platform "$PLATFORM"

set_env_var IMAGE_TAG "$IMAGE_TAG"
set_env_var MYSQL_IMAGE_TAG "$IMAGE_TAG"

echo "Built and pushed user-portal:${IMAGE_TAG} and user-data:${IMAGE_TAG}."
