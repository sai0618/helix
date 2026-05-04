#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
NAMESPACE="helix"
SERVICE_NAME="helix-user-portal"
INGRESS_NAME="helix-user-portal-external"
CONTEXT=""
LOCAL_PORT="8080"

usage() {
  cat <<USAGE
Usage:
  scripts/get_user_portal_url.sh --project-id PROJECT_ID [options]

Options:
  --project-id PROJECT_ID  GCP project ID. Required.
  --namespace NAME         Kubernetes namespace. Default: helix.
  --service-name NAME      Kubernetes service name. Default: helix-user-portal.
  --ingress-name NAME      Kubernetes ingress name. Default: helix-user-portal-external.
  --context NAME           Kube context. Default: primary sandbox cluster.
  --local-port PORT        Suggested local port-forward port. Default: 8080.
  -h, --help               Show this help.
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
    --ingress-name)
      INGRESS_NAME="$2"
      shift 2
      ;;
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --local-port)
      LOCAL_PORT="$2"
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

ingress_host="$(
  kubectl --context "$CONTEXT" -n "$NAMESPACE" \
    get ingress "$INGRESS_NAME" \
    -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true
)"

ingress_ip="$(
  kubectl --context "$CONTEXT" -n "$NAMESPACE" \
    get ingress "$INGRESS_NAME" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true
)"

if [[ -n "$ingress_ip" && -n "$ingress_host" ]]; then
  echo "http://${ingress_host}"
  exit 0
fi

if [[ -n "$ingress_ip" ]]; then
  echo "http://${ingress_ip}"
  exit 0
fi

service_type="$(
  kubectl --context "$CONTEXT" -n "$NAMESPACE" \
    get svc "$SERVICE_NAME" \
    -o jsonpath='{.spec.type}' 2>/dev/null || true
)"

if [[ "$service_type" == "LoadBalancer" ]]; then
  external_ip="$(
    kubectl --context "$CONTEXT" -n "$NAMESPACE" \
      get svc "$SERVICE_NAME" \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true
  )"
  external_hostname="$(
    kubectl --context "$CONTEXT" -n "$NAMESPACE" \
      get svc "$SERVICE_NAME" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
  )"

  if [[ -n "$external_ip" ]]; then
    echo "http://${external_ip}:8080"
    exit 0
  fi

  if [[ -n "$external_hostname" ]]; then
    echo "http://${external_hostname}:8080"
    exit 0
  fi
fi

echo "No external URL is currently assigned for service ${NAMESPACE}/${SERVICE_NAME}."
echo "Use local port-forward access:"
echo
echo "  PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:\$PATH USE_GKE_GCLOUD_AUTH_PLUGIN=True scripts/open_user_portal.sh --project-id ${PROJECT_ID} --local-port ${LOCAL_PORT}"
echo
echo "Then open:"
echo "  http://localhost:${LOCAL_PORT}"
