locals {
  labels = {
    app         = var.name_prefix
    environment = var.environment
    managed_by  = "terraform"
  }

  base_project_services = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "serviceusage.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudtrace.googleapis.com",
    "clouderrorreporting.googleapis.com",
  ]

  observability_project_services = concat(
    var.enable_cloud_logging ? ["logging.googleapis.com"] : [],
    var.enable_cloud_monitoring ? ["monitoring.googleapis.com"] : [],
  )

  traffic_project_services = concat(
    var.enable_fleet_registration || var.enable_cloud_service_mesh || var.enable_multi_cluster_ingress ? ["gkehub.googleapis.com"] : [],
    var.enable_cloud_service_mesh ? ["mesh.googleapis.com"] : [],
    var.enable_multi_cluster_ingress ? [
      "multiclusteringress.googleapis.com",
      "multiclusterservicediscovery.googleapis.com",
    ] : [],
  )

  required_project_services = distinct(concat(
    local.base_project_services,
    local.observability_project_services,
    local.traffic_project_services,
  ))

  vpc_name = "${var.name_prefix}-${var.environment}-vpc"

  subnets = {
    primary-gke = {
      name          = "${var.name_prefix}-${var.environment}-gke-primary-subnet"
      region        = var.primary_region
      ip_cidr_range = "10.10.0.0/20"
      secondary_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "10.20.0.0/16"
        },
        {
          range_name    = "services"
          ip_cidr_range = "10.30.0.0/20"
        },
      ]
    }
    secondary-gke = {
      name          = "${var.name_prefix}-${var.environment}-gke-secondary-subnet"
      region        = var.secondary_region
      ip_cidr_range = "10.11.0.0/20"
      secondary_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "10.40.0.0/16"
        },
        {
          range_name    = "services"
          ip_cidr_range = "10.50.0.0/20"
        },
      ]
    }
    ops = {
      name             = "${var.name_prefix}-${var.environment}-ops-subnet"
      region           = var.primary_region
      ip_cidr_range    = "10.12.0.0/24"
      secondary_ranges = []
    }
    primary-lb = {
      name             = "${var.name_prefix}-${var.environment}-lb-primary-subnet"
      region           = var.primary_region
      ip_cidr_range    = "10.13.0.0/24"
      secondary_ranges = []
    }
    secondary-lb = {
      name             = "${var.name_prefix}-${var.environment}-lb-secondary-subnet"
      region           = var.secondary_region
      ip_cidr_range    = "10.14.0.0/24"
      secondary_ranges = []
    }
  }

  internal_source_ranges = [
    for subnet in local.subnets : subnet.ip_cidr_range
  ]

  pod_source_ranges = flatten([
    for subnet in local.subnets : [
      for secondary_range in subnet.secondary_ranges : secondary_range.ip_cidr_range
      if secondary_range.range_name == "pods"
    ]
  ])

  service_accounts = {
    gke_nodes = {
      account_id   = "${var.name_prefix}-${var.environment}-gke-nodes"
      display_name = "Helix ${var.environment} GKE node service account"
      roles = [
        "roles/artifactregistry.reader",
        "roles/cloudtrace.agent",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
      ]
    }
    workload_ui = {
      account_id   = "${var.name_prefix}-${var.environment}-ui"
      display_name = "Helix ${var.environment} UI workload service account"
      roles = [
        "roles/cloudtrace.agent",
      ]
    }
    workload_api = {
      account_id   = "${var.name_prefix}-${var.environment}-api"
      display_name = "Helix ${var.environment} API workload service account"
      roles = [
        "roles/datastore.user",
      ]
    }
    cicd = {
      account_id   = "${var.name_prefix}-${var.environment}-cicd"
      display_name = "Helix ${var.environment} CI/CD service account"
      roles = [
        "roles/artifactregistry.writer",
        "roles/iam.serviceAccountUser",
      ]
    }
  }

  project_iam_bindings = {
    dev = {
      principals = var.project_iam_principals.dev
      roles = [
        "roles/artifactregistry.reader",
        "roles/cloudtrace.user",
        "roles/container.viewer",
        "roles/datastore.viewer",
        "roles/logging.viewer",
        "roles/monitoring.viewer",
      ]
    }
    ops = {
      principals = var.project_iam_principals.ops
      roles = [
        "roles/compute.networkViewer",
        "roles/cloudtrace.user",
        "roles/container.viewer",
        "roles/logging.viewer",
        "roles/monitoring.alertPolicyEditor",
        "roles/monitoring.viewer",
        "roles/serviceusage.serviceUsageViewer",
      ]
    }
    sre = {
      principals = var.project_iam_principals.sre
      roles = [
        "roles/compute.networkAdmin",
        "roles/cloudtrace.user",
        "roles/container.admin",
        "roles/iam.serviceAccountUser",
        "roles/logging.configWriter",
        "roles/logging.viewer",
        "roles/monitoring.admin",
      ]
    }
    cicd = {
      principals = var.project_iam_principals.cicd
      roles = [
        "roles/artifactregistry.writer",
        "roles/cloudbuild.builds.editor",
        "roles/container.developer",
        "roles/iam.serviceAccountUser",
        "roles/serviceusage.serviceUsageConsumer",
      ]
    }
  }

  gke_clusters = {
    primary = {
      name                   = "${var.name_prefix}-${var.environment}-primary-gke"
      location               = var.primary_zone
      subnet_key             = "primary-gke"
      master_ipv4_cidr_block = "172.16.0.0/28"
    }
    secondary = {
      name                   = "${var.name_prefix}-${var.environment}-secondary-gke"
      location               = var.secondary_zone
      subnet_key             = "secondary-gke"
      master_ipv4_cidr_block = "172.16.0.16/28"
    }
  }

  default_compute_engine_service_account = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  gke_node_service_account_email = var.gke_node_service_account_email != "" ? var.gke_node_service_account_email : local.default_compute_engine_service_account

  observability = {
    cloud_logging_enabled      = var.enable_cloud_logging
    cloud_monitoring_enabled   = var.enable_cloud_monitoring
    managed_prometheus_enabled = var.enable_cloud_monitoring
  }

  cloud_sql = {
    instance_name    = "${var.name_prefix}-${var.environment}-mysql"
    database_name    = "helix_users"
    database_user    = "helix_app"
    init_bucket_name = "${var.project_id}-${var.name_prefix}-${var.environment}-mysql-init"
  }

  log_export_cluster_filter = join(" OR ", [
    for cluster in local.gke_clusters : "resource.labels.cluster_name=\"${cluster.name}\""
  ])

  bigquery_log_exports = {
    user_portal_app = {
      dataset_id  = replace("${var.name_prefix}_${var.environment}_user_portal_app_logs", "-", "_")
      location    = var.log_export_dataset_location
      sink_name   = "${var.name_prefix}-${var.environment}-user-portal-app-logs-bq"
      description = "Structured JSON logs emitted by the user-portal application pods."
      filter      = <<-EOT
        resource.type="k8s_container"
        resource.labels.namespace_name="helix"
        resource.labels.container_name="user-portal"
        jsonPayload.service="user-portal"
      EOT
    }
    gke_control_plane = {
      dataset_id  = replace("${var.name_prefix}_${var.environment}_gke_control_plane_logs", "-", "_")
      location    = var.log_export_dataset_location
      sink_name   = "${var.name_prefix}-${var.environment}-gke-control-plane-logs-bq"
      description = "GKE control plane and Kubernetes audit logs for Helix clusters."
      filter      = <<-EOT
        resource.type="k8s_cluster"
        (${local.log_export_cluster_filter})
      EOT
    }
    gke_node = {
      dataset_id  = replace("${var.name_prefix}_${var.environment}_gke_node_logs", "-", "_")
      location    = var.log_export_dataset_location
      sink_name   = "${var.name_prefix}-${var.environment}-gke-node-logs-bq"
      description = "GKE node, kubelet, and node-level logs for Helix clusters."
      filter      = <<-EOT
        resource.type="k8s_node"
        (${local.log_export_cluster_filter})
      EOT
    }
  }

  app_login_secret_id         = "${var.name_prefix}-${var.environment}-app-login-credentials"
  mysql_credentials_secret_id = "${var.name_prefix}-${var.environment}-mysql-credentials"

  app_login_secret_payload = jsonencode({
    username      = var.app_login_username
    password      = var.app_login_password_hash == "" ? var.app_login_password : null
    password_hash = var.app_login_password_hash == "" ? null : var.app_login_password_hash
  })

  mysql_credentials_secret_payload = jsonencode({
    username = var.mysql_credentials_username
    password = var.mysql_credentials_password
    database = var.mysql_credentials_database
    host     = var.mysql_credentials_host
    port     = var.mysql_credentials_port
  })

  application_secrets = {
    app_login = {
      secret_id = local.app_login_secret_id
      payload   = local.app_login_secret_payload
      labels    = local.labels
    }
    mysql_credentials = {
      secret_id = local.mysql_credentials_secret_id
      payload   = local.mysql_credentials_secret_payload
      labels    = local.labels
    }
  }

  gke_fleet_clusters = {
    for key, cluster in module.gke_clusters :
    key => {
      membership_id = "${var.name_prefix}-${var.environment}-${key}"
      cluster_id    = cluster.id
    }
  }
}
