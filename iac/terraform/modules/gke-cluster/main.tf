resource "google_container_cluster" "cluster" {
  project  = var.project_id
  name     = var.name
  location = var.location

  network    = var.network
  subnetwork = var.subnetwork

  deletion_protection      = false
  initial_node_count       = 1
  remove_default_node_pool = true
  networking_mode          = "VPC_NATIVE"

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  secret_manager_config {
    enabled = var.enable_secret_manager_csi
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  logging_config {
    enable_components = var.enable_cloud_logging ? var.cloud_logging_components : []
  }

  monitoring_config {
    enable_components = var.enable_cloud_monitoring ? var.cloud_monitoring_components : []

    managed_prometheus {
      enabled = var.enable_cloud_monitoring && var.enable_managed_prometheus
    }
  }

  resource_labels = var.labels
}

resource "google_container_node_pool" "app" {
  project  = var.project_id
  name     = "app-pool"
  location = var.location
  cluster  = google_container_cluster.cluster.name

  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = "pd-standard"
    image_type      = "COS_CONTAINERD"
    service_account = var.node_service_account
    spot            = var.use_spot_nodes

    labels = var.labels
    tags   = ["gke-node", var.name]

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
