variable "project_id" {
  description = "Existing GCP project ID where resources will be provisioned."
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming and labels."
  type        = string
  default     = "sandbox"
}

variable "name_prefix" {
  description = "Short prefix for GCP resource names."
  type        = string
  default     = "helix"
}

variable "primary_region" {
  description = "Primary GCP region."
  type        = string
  default     = "us-central1"
}

variable "secondary_region" {
  description = "Secondary GCP region."
  type        = string
  default     = "us-east1"
}

variable "primary_zone" {
  description = "Primary GKE zone. Zonal clusters keep sandbox node count and quota usage low."
  type        = string
  default     = "us-central1-a"
}

variable "secondary_zone" {
  description = "Secondary GKE zone. Zonal clusters keep sandbox node count and quota usage low."
  type        = string
  default     = "us-east1-b"
}

variable "admin_source_ranges" {
  description = "CIDR ranges allowed for restricted admin access. Keep empty unless needed."
  type        = list(string)
  default     = []
}

variable "create_project_iam_bindings" {
  description = "Whether Terraform should create project-level IAM bindings. Google Cloud Sandbox projects may deny this."
  type        = bool
  default     = false
}

variable "enable_gke_clusters" {
  description = "Whether to create the primary and secondary GKE clusters."
  type        = bool
  default     = false
}

variable "gke_node_service_account_email" {
  description = "Optional service account email for GKE nodes. Leave empty to use the default Compute Engine service account, which is friendlier to Google Cloud Sandbox IAM limits."
  type        = string
  default     = ""
}

variable "enable_cloud_logging" {
  description = "Whether to enable Cloud Logging API and GKE log collection."
  type        = bool
  default     = true
}

variable "enable_cloud_monitoring" {
  description = "Whether to enable Cloud Monitoring API, GKE metric collection, and managed Prometheus."
  type        = bool
  default     = true
}

variable "enable_bigquery_log_sinks" {
  description = "Whether to create BigQuery datasets and Cloud Logging sinks for application and GKE logs."
  type        = bool
  default     = false
}

variable "log_export_dataset_location" {
  description = "BigQuery dataset location for log exports."
  type        = string
  default     = "US"
}

variable "delete_log_export_data_on_destroy" {
  description = "Whether Terraform destroy should delete BigQuery log export dataset contents."
  type        = bool
  default     = false
}

variable "log_export_viewer_members" {
  description = "IAM members that can list and query BigQuery log export tables. Use IAM member syntax, for example user:name@example.com."
  type        = list(string)
  default     = []
}

variable "enable_secret_manager_csi" {
  description = "Whether to enable the GKE Secret Manager CSI driver add-on for mounting Secret Manager secrets into pods."
  type        = bool
  default     = true
}

variable "enable_fleet_registration" {
  description = "Whether to register GKE clusters to the project GKE Fleet. Required for Cloud Service Mesh and Multi Cluster Ingress."
  type        = bool
  default     = false
}

variable "enable_cloud_service_mesh" {
  description = "Whether to enable managed Cloud Service Mesh on fleet-registered GKE clusters."
  type        = bool
  default     = false
}

variable "enable_multi_cluster_ingress" {
  description = "Whether to enable GKE Multi Cluster Ingress using the primary cluster as the config cluster."
  type        = bool
  default     = false
}

variable "enable_ingress_foundation" {
  description = "Whether to reserve static IPs for external and internal ingress/load balancers."
  type        = bool
  default     = false
}

variable "enable_cloud_sql" {
  description = "Whether to create the Cloud SQL MySQL database for the user registration app."
  type        = bool
  default     = false
}

variable "cloud_sql_database_password" {
  description = "Password for the Cloud SQL application database user."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_cloud_sql_import" {
  description = "Whether Terraform should import apps/user-data/init.sql into Cloud SQL using gcloud."
  type        = bool
  default     = false
}

variable "enable_secret_manager_secrets" {
  description = "Whether to create Secret Manager secrets for the user portal login and MySQL credentials."
  type        = bool
  default     = false
}

variable "app_login_username" {
  description = "Application login username stored in Secret Manager."
  type        = string
  default     = "admin"
}

variable "app_login_password" {
  description = "Application login password stored in Secret Manager. Prefer app_login_password_hash for non-sandbox use."
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_login_password_hash" {
  description = "Werkzeug-compatible password hash for the application login. If set, the app ignores app_login_password."
  type        = string
  sensitive   = true
  default     = ""
}

variable "mysql_credentials_username" {
  description = "MySQL application username stored in Secret Manager."
  type        = string
  default     = "helix_app"
}

variable "mysql_credentials_password" {
  description = "MySQL application password stored in Secret Manager."
  type        = string
  sensitive   = true
  default     = ""
}

variable "mysql_credentials_database" {
  description = "MySQL database name stored in Secret Manager."
  type        = string
  default     = "helix_users"
}

variable "mysql_credentials_host" {
  description = "MySQL host stored in Secret Manager. Use the MySQL Helm service name for in-cluster StatefulSet MySQL, or Cloud SQL proxy/service host later."
  type        = string
  default     = "helix-mysql"
}

variable "mysql_credentials_port" {
  description = "MySQL port stored in Secret Manager."
  type        = string
  default     = "3306"
}

variable "secret_accessor_members" {
  description = "Optional IAM members that can access the application secrets. For GKE Workload Identity, use a principal URI for the Kubernetes service account."
  type        = list(string)
  default     = []
}

variable "project_iam_principals" {
  description = "IAM principals for project-level Dev, Ops, SRE, and CI/CD personas. Use IAM member syntax: user:name@example.com, group:name@example.com, or serviceAccount:name@project.iam.gserviceaccount.com."
  type = object({
    dev  = list(string)
    ops  = list(string)
    sre  = list(string)
    cicd = list(string)
  })
  default = {
    dev  = []
    ops  = []
    sre  = []
    cicd = []
  }
}
