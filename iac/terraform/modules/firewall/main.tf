resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-internal"
  network = var.network

  description   = "Allow internal VPC, pod, and service communication."
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.internal_source_ranges

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_google_health_checks" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-google-health-checks"
  network = var.network

  description = "Allow Google load balancer and health check probes."
  direction   = "INGRESS"
  priority    = 1000
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_firewall" "allow_iap_admin" {
  count = length(var.admin_source_ranges) > 0 ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-allow-admin"
  network = var.network

  description   = "Optional restricted administrative access."
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.admin_source_ranges

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }
}
