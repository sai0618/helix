variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "region" {
  description = "Cloud SQL region."
  type        = string
}

variable "instance_name" {
  description = "Cloud SQL instance name."
  type        = string
}

variable "database_name" {
  description = "Application database name."
  type        = string
}

variable "database_user" {
  description = "Application database user."
  type        = string
}

variable "database_password" {
  description = "Application database password."
  type        = string
  sensitive   = true
}

variable "private_network" {
  description = "VPC self link used for private Cloud SQL connectivity."
  type        = string
}

variable "labels" {
  description = "Labels applied to Cloud SQL resources."
  type        = map(string)
  default     = {}
}

variable "tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size_gb" {
  description = "Cloud SQL disk size in GB."
  type        = number
  default     = 10
}

variable "init_sql_source_path" {
  description = "Local path to the SQL initialization file."
  type        = string
}

variable "init_bucket_name" {
  description = "GCS bucket name for Cloud SQL import SQL files."
  type        = string
}

variable "enable_sql_import" {
  description = "Whether Terraform should run gcloud sql import sql for the initialization script."
  type        = bool
  default     = false
}
