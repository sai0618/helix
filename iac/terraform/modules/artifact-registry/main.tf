resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.location
  repository_id = "${var.name_prefix}-docker"
  description   = "Docker images for Helix applications."
  format        = "DOCKER"
  labels        = var.labels
}

resource "google_artifact_registry_repository" "helm" {
  project       = var.project_id
  location      = var.location
  repository_id = "${var.name_prefix}-helm"
  description   = "Helm charts for Helix applications."
  format        = "DOCKER"
  labels        = var.labels
}

resource "google_artifact_registry_repository_iam_member" "docker_readers" {
  for_each = toset(var.reader_service_accounts)

  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}

resource "google_artifact_registry_repository_iam_member" "helm_readers" {
  for_each = toset(var.reader_service_accounts)

  project    = var.project_id
  location   = google_artifact_registry_repository.helm.location
  repository = google_artifact_registry_repository.helm.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}

resource "google_artifact_registry_repository_iam_member" "docker_writers" {
  for_each = toset(var.writer_service_accounts)

  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${each.value}"
}

resource "google_artifact_registry_repository_iam_member" "helm_writers" {
  for_each = toset(var.writer_service_accounts)

  project    = var.project_id
  location   = google_artifact_registry_repository.helm.location
  repository = google_artifact_registry_repository.helm.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${each.value}"
}
