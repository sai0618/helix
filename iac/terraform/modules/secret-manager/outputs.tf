output "secret_ids" {
  description = "Secret Manager secret IDs by key."
  value = {
    for key, secret in google_secret_manager_secret.secrets :
    key => secret.secret_id
  }
}

output "secret_names" {
  description = "Secret Manager fully qualified secret resource names by key."
  value = {
    for key, secret in google_secret_manager_secret.secrets :
    key => secret.id
  }
}
