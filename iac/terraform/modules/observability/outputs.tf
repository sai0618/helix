output "dataset_ids" {
  description = "BigQuery dataset IDs by export key."
  value = {
    for key, dataset in google_bigquery_dataset.log_exports :
    key => dataset.dataset_id
  }
}

output "sink_names" {
  description = "Log sink names by export key."
  value = {
    for key, sink in google_logging_project_sink.log_exports :
    key => sink.name
  }
}

output "sink_writer_identities" {
  description = "Log sink writer identities by export key."
  value = {
    for key, sink in google_logging_project_sink.log_exports :
    key => sink.writer_identity
  }
}
