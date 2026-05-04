variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "services" {
  description = "Project APIs to enable."
  type        = set(string)
}
