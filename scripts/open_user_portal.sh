#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
NAMESPACE="helix"
SERVICE_NAME="helix-user-portal"
LOCAL_PORT="8080"
REMOTE_PORT="8080"
CONTEXT=""

usage() {
  cat <<USAGE
Usage:
  scripts/open_user_portal.sh --project-id PROJECT_ID [options]

Options:
  --project-id PROJECT_ID  GCP project ID. Required.
  --namespace NAME         Kubernetes namespace. Default: helix.
  --service-name NAME      Kubernetes service name. Default: helix-user-portal.
  --local-port PORT        Local browser port. Default: 8080.
  --remote-port PORT       Service port. Default: 8080.
  --context NAME           Kube context. Default: primary sandbox cluster.
  -h, --help               Show this help.

The script runs kubectl port-forward in the foreground.
Stop it with Ctrl+C when finished.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --local-port)
      LOCAL_PORT="$2"
      shift 2
      ;;
    --remote-port)
      REMOTE_PORT="$2"
      shift 2
      ;;
    --context)
      CONTEXT="$2"
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

if [[ -z "$CONTEXT" ]]; then
  CONTEXT="gke_${PROJECT_ID}_us-central1-a_helix-sandbox-primary-gke"
fi

echo "Opening user portal from context: $CONTEXT"
echo "URL: http://localhost:${LOCAL_PORT}"
echo "Press Ctrl+C to stop the tunnel."
echo

kubectl --context "$CONTEXT" \
  -n "$NAMESPACE" \
  port-forward "svc/${SERVICE_NAME}" "${LOCAL_PORT}:${REMOTE_PORT}"
