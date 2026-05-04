#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=""
NAMESPACE="helix"
RELEASE="helix-user-portal"
CONTEXT=""
STATIC_IP_NAME="helix-sandbox-external-https-ip"
HOST=""
IP_ADDRESS=""

usage() {
  cat <<USAGE
Usage:
  scripts/expose_user_portal_external.sh --project-id PROJECT_ID [options]

Options:
  --project-id PROJECT_ID       GCP project ID. Required.
  --namespace NAME              Kubernetes namespace. Default: helix.
  --release NAME                Helm release name. Default: helix-user-portal.
  --context NAME                Kube context. Default: primary sandbox cluster.
  --static-ip-name NAME         GCP global static IP name. Default: helix-sandbox-external-https-ip.
  --host HOST                   DNS hostname. Default: helix.<STATIC_IP>.sslip.io.
  -h, --help                    Show this help.

This configures a GKE external HTTP Ingress for the existing user portal Helm release.
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
    --release)
      RELEASE="$2"
      shift 2
      ;;
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --static-ip-name)
      STATIC_IP_NAME="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
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

IP_ADDRESS="$(
  gcloud compute addresses describe "$STATIC_IP_NAME" \
    --global \
    --project "$PROJECT_ID" \
    --format='value(address)'
)"

if [[ -z "$HOST" ]]; then
  HOST="helix.${IP_ADDRESS}.sslip.io"
fi

helm upgrade "$RELEASE" ./helm-charts/user-portal \
  --namespace "$NAMESPACE" \
  --kube-context "$CONTEXT" \
  --reuse-values \
  --set externalIngress.enabled=true \
  --set externalIngress.staticIpName="$STATIC_IP_NAME" \
  --set externalIngress.host="$HOST"

echo
echo "External ingress requested."
echo "DNS URL: http://${HOST}"
echo "Static IP: http://${IP_ADDRESS}"
echo
echo "GKE load balancer provisioning can take several minutes."
echo "Check status:"
echo "  kubectl --context $CONTEXT -n $NAMESPACE get ingress ${RELEASE}-external"
