resource "google_compute_global_address" "private_service_access" {
  project       = var.project_id
  name          = var.reserved_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.reserved_prefix
  network       = var.vpc_id
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
}
