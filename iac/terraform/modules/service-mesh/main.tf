resource "google_gke_hub_feature" "service_mesh" {
  project  = var.project_id
  name     = "servicemesh"
  location = "global"
  labels   = var.labels
}

resource "google_gke_hub_feature_membership" "service_mesh" {
  for_each = var.memberships

  project             = var.project_id
  location            = google_gke_hub_feature.service_mesh.location
  feature             = google_gke_hub_feature.service_mesh.name
  membership          = each.value.membership_id
  membership_location = each.value.membership_location

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }
}
