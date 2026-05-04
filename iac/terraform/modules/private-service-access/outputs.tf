output "reserved_range_name" {
  description = "Private Service Access reserved range name."
  value       = google_compute_global_address.private_service_access.name
}

output "connection_id" {
  description = "Private Service Access connection ID."
  value       = google_service_networking_connection.private_service_access.id
}
