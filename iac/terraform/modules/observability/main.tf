resource "google_bigquery_dataset" "log_exports" {
  for_each = var.log_exports

  project                    = var.project_id
  dataset_id                 = each.value.dataset_id
  location                   = each.value.location
  description                = each.value.description
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = var.labels

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }
}

resource "google_logging_project_sink" "log_exports" {
  for_each = var.log_exports

  project                = var.project_id
  name                   = each.value.sink_name
  description            = each.value.description
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.log_exports[each.key].dataset_id}"
  filter                 = each.value.filter
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "sink_writers" {
  for_each = var.log_exports

  project    = var.project_id
  dataset_id = google_bigquery_dataset.log_exports[each.key].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.log_exports[each.key].writer_identity
}

locals {
  dataset_viewer_bindings = {
    for pair in setproduct(keys(var.log_exports), var.dataset_viewer_members) :
    "${pair[0]}:${pair[1]}" => {
      export_key = pair[0]
      member     = pair[1]
    }
  }
}

resource "google_bigquery_dataset_iam_member" "dataset_viewers" {
  for_each = local.dataset_viewer_bindings

  project    = var.project_id
  dataset_id = google_bigquery_dataset.log_exports[each.value.export_key].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = each.value.member
}
