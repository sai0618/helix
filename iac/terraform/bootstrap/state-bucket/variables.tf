variable "project_id" {
  description = "Existing GCP project ID where the Terraform state bucket will be created."
  type        = string
}

variable "region" {
  description = "Region for the Terraform state bucket."
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Globally unique GCS bucket name for Terraform state."
  type        = string
}

variable "labels" {
  description = "Labels to apply to the state bucket."
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}
