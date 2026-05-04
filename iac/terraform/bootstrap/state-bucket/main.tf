resource "google_project_service" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_storage_bucket" "terraform_state" {
  project  = var.project_id
  name     = var.bucket_name
  location = var.region
  labels   = var.labels

  force_destroy               = false
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }

    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.storage]
}
