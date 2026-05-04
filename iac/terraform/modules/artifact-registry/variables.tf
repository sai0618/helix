variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "location" {
  description = "Artifact Registry location."
  type        = string
}

variable "name_prefix" {
  description = "Repository name prefix."
  type        = string
}

variable "labels" {
  description = "Labels to apply to repositories."
  type        = map(string)
  default     = {}
}

variable "reader_service_accounts" {
  description = "Service account emails that can read artifacts."
  type        = list(string)
  default     = []
}

variable "writer_service_accounts" {
  description = "Service account emails that can write artifacts."
  type        = list(string)
  default     = []
}
