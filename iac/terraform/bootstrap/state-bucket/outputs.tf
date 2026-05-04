output "bucket_name" {
  description = "Terraform state bucket name."
  value       = google_storage_bucket.terraform_state.name
}

output "backend_config" {
  description = "Backend config values for the sandbox environment."
  value = {
    bucket = google_storage_bucket.terraform_state.name
    prefix = "helix/sandbox"
  }
}
