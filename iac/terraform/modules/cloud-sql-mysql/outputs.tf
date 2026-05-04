output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.mysql.name
}

output "connection_name" {
  description = "Cloud SQL connection name."
  value       = google_sql_database_instance.mysql.connection_name
}

output "private_ip_address" {
  description = "Cloud SQL private IP address."
  value       = google_sql_database_instance.mysql.private_ip_address
}

output "database_name" {
  description = "Application database name."
  value       = google_sql_database.app.name
}

output "database_user" {
  description = "Application database user."
  value       = google_sql_user.app.name
}

output "init_sql_gcs_uri" {
  description = "GCS URI for the SQL initialization file."
  value       = "gs://${google_storage_bucket.init_sql.name}/${google_storage_bucket_object.init_sql.name}"
}
