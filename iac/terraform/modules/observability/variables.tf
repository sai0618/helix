variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "labels" {
  description = "Labels to apply to datasets."
  type        = map(string)
  default     = {}
}

variable "delete_contents_on_destroy" {
  description = "Whether BigQuery dataset contents should be deleted when Terraform destroys the dataset."
  type        = bool
  default     = false
}

variable "dataset_viewer_members" {
  description = "IAM members that can list and query exported log tables in each BigQuery dataset."
  type        = list(string)
  default     = []
}

variable "log_exports" {
  description = "BigQuery log export sinks keyed by logical name."
  type = map(object({
    dataset_id  = string
    location    = string
    sink_name   = string
    description = string
    filter      = string
  }))
}
