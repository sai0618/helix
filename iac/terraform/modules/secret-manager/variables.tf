variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secrets" {
  description = "Secret Manager secrets to create."
  type = map(object({
    secret_id = string
    payload   = string
    labels    = optional(map(string), {})
  }))
}

variable "accessor_members" {
  description = "IAM members that can access every secret. Use full IAM member syntax or principal URIs."
  type        = list(string)
  default     = []
}

variable "replication_locations" {
  description = "User-managed Secret Manager replication locations. Leave empty for automatic replication."
  type        = list(string)
  default     = []
}
