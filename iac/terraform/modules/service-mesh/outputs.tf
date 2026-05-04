output "feature_name" {
  description = "Cloud Service Mesh fleet feature name."
  value       = google_gke_hub_feature.service_mesh.name
}

output "managed_memberships" {
  description = "Fleet memberships configured for managed Cloud Service Mesh."
  value       = keys(google_gke_hub_feature_membership.service_mesh)
}
