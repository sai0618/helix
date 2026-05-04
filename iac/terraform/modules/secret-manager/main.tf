resource "google_secret_manager_secret" "secrets" {
  for_each = nonsensitive(var.secrets)

  project   = var.project_id
  secret_id = each.value.secret_id
  labels    = each.value.labels

  replication {
    dynamic "auto" {
      for_each = length(var.replication_locations) == 0 ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = length(var.replication_locations) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = toset(var.replication_locations)
          content {
            location = replicas.value
          }
        }
      }
    }
  }
}

resource "google_secret_manager_secret_version" "versions" {
  for_each = nonsensitive(var.secrets)

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value.payload
}

locals {
  secret_accessors = {
    for pair in setproduct(keys(nonsensitive(var.secrets)), var.accessor_members) :
    "${pair[0]}:${pair[1]}" => {
      secret_key = pair[0]
      member     = pair[1]
    }
  }
}

resource "google_secret_manager_secret_iam_member" "accessors" {
  for_each = local.secret_accessors

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret_key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
