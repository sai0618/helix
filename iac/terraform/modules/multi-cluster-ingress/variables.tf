variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "labels" {
  description = "Labels applied to fleet features."
  type        = map(string)
  default     = {}
}

variable "config_membership" {
  description = "Fully qualified fleet membership resource name for the MCI config cluster."
  type        = string
}
