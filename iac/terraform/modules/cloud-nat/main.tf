resource "google_compute_router" "routers" {
  for_each = var.regions

  project = var.project_id
  name    = "${var.name_prefix}-${each.value}-router"
  region  = each.value
  network = var.network
}

resource "google_compute_router_nat" "nats" {
  for_each = var.regions

  project                            = var.project_id
  name                               = "${var.name_prefix}-${each.value}-nat"
  router                             = google_compute_router.routers[each.value].name
  region                             = each.value
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
