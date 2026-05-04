variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "vpc_name" {
  description = "VPC name."
  type        = string
}

variable "vpc_id" {
  description = "VPC resource ID."
  type        = string
}

variable "reserved_range_name" {
  description = "Name for the Private Service Access reserved range."
  type        = string
}

variable "reserved_prefix" {
  description = "Prefix length for the Private Service Access reserved range."
  type        = number
  default     = 16
}
