variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "network" {
  description = "VPC name."
  type        = string
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "internal_source_ranges" {
  description = "CIDR ranges allowed for internal VPC and GKE pod communication."
  type        = list(string)
}

variable "admin_source_ranges" {
  description = "CIDR ranges allowed for restricted admin access."
  type        = list(string)
  default     = []
}
