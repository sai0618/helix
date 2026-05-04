output "enabled_services" {
  description = "Enabled project APIs."
  value       = keys(google_project_service.services)
}
