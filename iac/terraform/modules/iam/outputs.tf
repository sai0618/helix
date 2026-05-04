output "service_account_emails" {
  description = "Service account emails by key."
  value = {
    for key, service_account in google_service_account.service_accounts :
    key => service_account.email
  }
}

output "service_account_ids" {
  description = "Service account resource IDs by key."
  value = {
    for key, service_account in google_service_account.service_accounts :
    key => service_account.id
  }
}

output "project_iam_personas" {
  description = "Project IAM persona keys configured for role bindings."
  value       = keys(var.project_iam_bindings)
}
