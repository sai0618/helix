resource "google_gke_hub_membership" "memberships" {
  for_each = var.clusters

  project       = var.project_id
  location      = var.location
  membership_id = each.value.membership_id
  labels        = var.labels

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${each.value.cluster_id}"
    }
  }

  authority {
    issuer = "https://container.googleapis.com/v1/${each.value.cluster_id}"
  }
}
