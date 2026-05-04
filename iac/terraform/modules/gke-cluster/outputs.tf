output "name" {
  description = "GKE cluster name."
  value       = google_container_cluster.cluster.name
}

output "id" {
  description = "GKE cluster resource ID."
  value       = google_container_cluster.cluster.id
}

output "location" {
  description = "GKE cluster location."
  value       = google_container_cluster.cluster.location
}

output "endpoint" {
  description = "GKE cluster endpoint."
  value       = google_container_cluster.cluster.endpoint
  sensitive   = true
}

output "node_pool_name" {
  description = "Application node pool name."
  value       = google_container_node_pool.app.name
}
