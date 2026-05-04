resource "google_compute_global_address" "external_https" {
  project     = var.project_id
  name        = "${var.name_prefix}-external-https-ip"
  description = "Global static IP for external HTTPS ingress or Multi Cluster Ingress."
  labels      = var.labels
}

resource "google_compute_address" "internal_ingress" {
  project      = var.project_id
  name         = "${var.name_prefix}-internal-ingress-ip"
  region       = var.region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = var.subnetwork_self_link
  description  = "Regional static IP for internal GKE ingress."
}
