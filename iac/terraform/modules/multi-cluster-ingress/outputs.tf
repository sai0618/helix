output "feature_name" {
  description = "Multi Cluster Ingress fleet feature name."
  value       = google_gke_hub_feature.multi_cluster_ingress.name
}

output "config_membership" {
  description = "Fleet membership used as the MCI config cluster."
  value       = var.config_membership
}
