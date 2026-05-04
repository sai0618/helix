variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "network" {
  description = "VPC self link."
  type        = string
}

variable "regions" {
  description = "Regions where Cloud Router and Cloud NAT should be created."
  type        = set(string)
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}
