output "project_id" {
  description = "Existing GCP project ID."
  value       = data.google_project.current.project_id
}

output "vpc_name" {
  description = "Provisioned VPC name."
  value       = module.network.vpc_name
}

output "subnets" {
  description = "Provisioned subnet names by key."
  value       = module.network.subnet_names
}

output "service_account_emails" {
  description = "Created service account emails by key."
  value       = module.iam.service_account_emails
}

output "project_iam_personas" {
  description = "Project-level IAM personas configured for role bindings."
  value       = module.iam.project_iam_personas
}

output "artifact_registry_repositories" {
  description = "Artifact Registry repository IDs."
  value       = module.artifact_registry.repository_ids
}

output "private_service_access_reserved_range" {
  description = "Reserved range for Private Service Access."
  value       = module.private_service_access.reserved_range_name
}

output "cloud_nat_names" {
  description = "Cloud NAT names by region."
  value       = module.cloud_nat.nat_names
}

output "gke_clusters" {
  description = "GKE cluster names and locations."
  value = {
    for key, cluster in module.gke_clusters :
    key => {
      name     = cluster.name
      location = cluster.location
      id       = cluster.id
    }
  }
}

output "fleet_memberships" {
  description = "GKE Fleet memberships by cluster key."
  value = {
    for key, fleet in module.fleet_memberships :
    key => fleet.memberships
  }
}

output "observability" {
  description = "Cloud Logging and Cloud Monitoring enablement."
  value = merge(local.observability, {
    bigquery_log_sinks_enabled = var.enable_bigquery_log_sinks
  })
}

output "bigquery_log_exports" {
  description = "BigQuery datasets and Cloud Logging sinks for exported logs."
  value = {
    for key, exports in module.observability_log_exports :
    key => {
      dataset_ids            = exports.dataset_ids
      sink_names             = exports.sink_names
      sink_writer_identities = exports.sink_writer_identities
    }
  }
}

output "cloud_sql_mysql" {
  description = "Cloud SQL MySQL database details."
  value = {
    for key, database in module.cloud_sql_mysql :
    key => {
      instance_name      = database.instance_name
      connection_name    = database.connection_name
      private_ip_address = database.private_ip_address
      database_name      = database.database_name
      database_user      = database.database_user
      init_sql_gcs_uri   = database.init_sql_gcs_uri
    }
  }
}

output "application_secret_ids" {
  description = "Secret Manager secret IDs for the user portal."
  value = {
    for key, module_instance in module.application_secrets :
    key => module_instance.secret_ids
  }
}

output "ingress_foundation" {
  description = "Static IP foundations for external and internal ingress."
  value = {
    for key, ingress in module.ingress_foundation :
    key => {
      external_https_ip_name      = ingress.external_https_ip_name
      external_https_ip_address   = ingress.external_https_ip_address
      internal_ingress_ip_name    = ingress.internal_ingress_ip_name
      internal_ingress_ip_address = ingress.internal_ingress_ip_address
    }
  }
}

output "cloud_service_mesh" {
  description = "Managed Cloud Service Mesh fleet feature details."
  value = {
    for key, mesh in module.cloud_service_mesh :
    key => {
      feature_name        = mesh.feature_name
      managed_memberships = mesh.managed_memberships
    }
  }
}

output "multi_cluster_ingress" {
  description = "Multi Cluster Ingress fleet feature details."
  value = {
    for key, ingress in module.multi_cluster_ingress :
    key => {
      feature_name      = ingress.feature_name
      config_membership = ingress.config_membership
    }
  }
}
