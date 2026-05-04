variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "location" {
  description = "Fleet membership location."
  type        = string
  default     = "global"
}

variable "labels" {
  description = "Labels applied to fleet memberships."
  type        = map(string)
  default     = {}
}

variable "clusters" {
  description = "GKE clusters to register to the fleet."
  type = map(object({
    membership_id = string
    cluster_id    = string
  }))
}
