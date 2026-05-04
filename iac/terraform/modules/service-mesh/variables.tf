variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "labels" {
  description = "Labels applied to fleet features."
  type        = map(string)
  default     = {}
}

variable "memberships" {
  description = "Fleet memberships that should run managed Cloud Service Mesh."
  type = map(object({
    membership_id       = string
    membership_location = string
  }))
}
