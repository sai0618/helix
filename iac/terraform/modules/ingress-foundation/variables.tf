variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for ingress resources."
  type        = string
}

variable "region" {
  description = "Primary region for regional internal load balancer resources."
  type        = string
}

variable "subnetwork_self_link" {
  description = "Subnetwork self link for the regional internal load balancer IP."
  type        = string
}

variable "labels" {
  description = "Labels applied to ingress foundation resources where supported."
  type        = map(string)
  default     = {}
}
