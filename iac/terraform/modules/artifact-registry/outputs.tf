output "repository_ids" {
  description = "Artifact Registry repository IDs."
  value = {
    docker = google_artifact_registry_repository.docker.repository_id
    helm   = google_artifact_registry_repository.helm.repository_id
  }
}

output "repository_names" {
  description = "Artifact Registry repository resource names."
  value = {
    docker = google_artifact_registry_repository.docker.name
    helm   = google_artifact_registry_repository.helm.name
  }
}
