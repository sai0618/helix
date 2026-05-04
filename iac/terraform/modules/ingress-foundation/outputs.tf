output "external_https_ip_name" {
  description = "Global external HTTPS ingress IP resource name."
  value       = google_compute_global_address.external_https.name
}

output "external_https_ip_address" {
  description = "Global external HTTPS ingress IP address."
  value       = google_compute_global_address.external_https.address
}

output "internal_ingress_ip_name" {
  description = "Regional internal ingress IP resource name."
  value       = google_compute_address.internal_ingress.name
}

output "internal_ingress_ip_address" {
  description = "Regional internal ingress IP address."
  value       = google_compute_address.internal_ingress.address
}
