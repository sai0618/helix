resource "google_gke_hub_feature" "multi_cluster_ingress" {
  project  = var.project_id
  name     = "multiclusteringress"
  location = "global"
  labels   = var.labels

  spec {
    multiclusteringress {
      config_membership = var.config_membership
    }
  }
}
