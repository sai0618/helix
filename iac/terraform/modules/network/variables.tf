variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "vpc_name" {
  description = "VPC name."
  type        = string
}

variable "subnets" {
  description = "Subnets keyed by logical name."
  type = map(object({
    name          = string
    region        = string
    ip_cidr_range = string
    secondary_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
}
