variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "service_accounts" {
  description = "Service accounts to create and project roles to bind."
  type = map(object({
    account_id   = string
    display_name = string
    roles        = list(string)
  }))
}

variable "create_project_iam_bindings" {
  description = "Whether to create project-level IAM role bindings for service accounts."
  type        = bool
  default     = true
}

variable "project_iam_bindings" {
  description = "Project-level IAM persona bindings. Members must use IAM member syntax, for example group:dev@example.com, user:alice@example.com, or serviceAccount:name@project.iam.gserviceaccount.com."
  type = map(object({
    principals = list(string)
    roles      = list(string)
  }))
  default = {}
}
