variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "name" {
  description = "GKE cluster name."
  type        = string
}

variable "location" {
  description = "GKE cluster region or zone."
  type        = string
}

variable "network" {
  description = "VPC self link."
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork self link."
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Secondary range name for pod IPs."
  type        = string
}

variable "services_secondary_range_name" {
  description = "Secondary range name for service IPs."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "Private control plane CIDR block. Must be a /28."
  type        = string
}

variable "node_service_account" {
  description = "Service account email for GKE nodes."
  type        = string
}

variable "labels" {
  description = "Labels applied to GKE resources."
  type        = map(string)
  default     = {}
}

variable "node_machine_type" {
  description = "Machine type for the default application node pool."
  type        = string
  default     = "e2-medium"
}

variable "node_disk_size_gb" {
  description = "Boot disk size in GB for nodes."
  type        = number
  default     = 20
}

variable "node_count" {
  description = "Initial node count for the application node pool."
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum autoscaled node count."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum autoscaled node count."
  type        = number
  default     = 1
}

variable "use_spot_nodes" {
  description = "Whether the node pool should use spot VMs to reduce sandbox cost."
  type        = bool
  default     = true
}

variable "enable_cloud_logging" {
  description = "Whether to send GKE system and workload logs to Cloud Logging."
  type        = bool
  default     = true
}

variable "cloud_logging_components" {
  description = "GKE logging components to send to Cloud Logging."
  type        = list(string)
  default = [
    "SYSTEM_COMPONENTS",
    "WORKLOADS",
  ]
}

variable "enable_cloud_monitoring" {
  description = "Whether to send GKE metrics to Cloud Monitoring."
  type        = bool
  default     = true
}

variable "cloud_monitoring_components" {
  description = "GKE monitoring components to send to Cloud Monitoring."
  type        = list(string)
  default = [
    "SYSTEM_COMPONENTS",
  ]
}

variable "enable_managed_prometheus" {
  description = "Whether to enable Google Cloud Managed Service for Prometheus on the cluster."
  type        = bool
  default     = true
}

variable "enable_secret_manager_csi" {
  description = "Whether to enable the GKE Secret Manager CSI driver add-on."
  type        = bool
  default     = true
}
