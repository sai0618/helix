data "google_project" "current" {
  project_id = var.project_id
}

module "project_services" {
  source = "../../modules/project-services"

  project_id = var.project_id
  services   = local.required_project_services
}

module "iam" {
  source = "../../modules/iam"

  project_id                  = var.project_id
  service_accounts            = local.service_accounts
  project_iam_bindings        = local.project_iam_bindings
  create_project_iam_bindings = var.create_project_iam_bindings

  depends_on = [module.project_services]
}

module "network" {
  source = "../../modules/network"

  project_id = var.project_id
  vpc_name   = local.vpc_name
  subnets    = local.subnets

  depends_on = [module.project_services]
}

module "private_service_access" {
  source = "../../modules/private-service-access"

  project_id          = var.project_id
  vpc_name            = module.network.vpc_name
  vpc_id              = module.network.vpc_id
  reserved_range_name = "${var.name_prefix}-${var.environment}-psa-range"
  reserved_prefix     = 16

  depends_on = [module.project_services, module.network]
}

module "cloud_nat" {
  source = "../../modules/cloud-nat"

  project_id  = var.project_id
  network     = module.network.vpc_self_link
  regions     = [var.primary_region, var.secondary_region]
  name_prefix = "${var.name_prefix}-${var.environment}"

  depends_on = [module.network]
}

module "firewall" {
  source = "../../modules/firewall"

  project_id             = var.project_id
  network                = module.network.vpc_name
  name_prefix            = "${var.name_prefix}-${var.environment}"
  internal_source_ranges = concat(local.internal_source_ranges, local.pod_source_ranges)
  admin_source_ranges    = var.admin_source_ranges

  depends_on = [module.network]
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id              = var.project_id
  location                = var.primary_region
  name_prefix             = "${var.name_prefix}-${var.environment}"
  labels                  = local.labels
  reader_service_accounts = [module.iam.service_account_emails["gke_nodes"]]
  writer_service_accounts = [module.iam.service_account_emails["cicd"]]

  depends_on = [module.project_services, module.iam]
}

module "cloud_sql_mysql" {
  for_each = var.enable_cloud_sql ? { main = local.cloud_sql } : {}

  source = "../../modules/cloud-sql-mysql"

  project_id           = var.project_id
  region               = var.primary_region
  instance_name        = each.value.instance_name
  database_name        = each.value.database_name
  database_user        = each.value.database_user
  database_password    = var.cloud_sql_database_password
  private_network      = module.network.vpc_self_link
  labels               = local.labels
  init_sql_source_path = "${path.root}/../../../../apps/user-data/init.sql"
  init_bucket_name     = each.value.init_bucket_name
  enable_sql_import    = var.enable_cloud_sql_import

  depends_on = [
    module.project_services,
    module.network,
    module.private_service_access,
  ]
}

module "application_secrets" {
  for_each = var.enable_secret_manager_secrets ? toset(["main"]) : toset([])

  source = "../../modules/secret-manager"

  project_id       = var.project_id
  secrets          = local.application_secrets
  accessor_members = var.secret_accessor_members
  replication_locations = [
    var.primary_region,
  ]

  depends_on = [module.project_services]
}

module "ingress_foundation" {
  for_each = var.enable_ingress_foundation ? toset(["main"]) : toset([])

  source = "../../modules/ingress-foundation"

  project_id           = var.project_id
  name_prefix          = "${var.name_prefix}-${var.environment}"
  region               = var.primary_region
  subnetwork_self_link = module.network.subnet_self_links["primary-lb"]
  labels               = local.labels

  depends_on = [module.project_services, module.network]
}

module "observability_log_exports" {
  for_each = var.enable_bigquery_log_sinks ? toset(["main"]) : toset([])

  source = "../../modules/observability"

  project_id                 = var.project_id
  labels                     = local.labels
  log_exports                = local.bigquery_log_exports
  delete_contents_on_destroy = var.delete_log_export_data_on_destroy
  dataset_viewer_members     = var.log_export_viewer_members

  depends_on = [module.project_services]
}

module "gke_clusters" {
  for_each = var.enable_gke_clusters ? local.gke_clusters : {}

  source = "../../modules/gke-cluster"

  project_id                    = var.project_id
  name                          = each.value.name
  location                      = each.value.location
  network                       = module.network.vpc_self_link
  subnetwork                    = module.network.subnet_self_links[each.value.subnet_key]
  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"
  master_ipv4_cidr_block        = each.value.master_ipv4_cidr_block
  node_service_account          = local.gke_node_service_account_email
  labels                        = local.labels
  enable_cloud_logging          = var.enable_cloud_logging
  enable_cloud_monitoring       = var.enable_cloud_monitoring
  enable_managed_prometheus     = var.enable_cloud_monitoring
  enable_secret_manager_csi     = var.enable_secret_manager_csi

  depends_on = [
    module.project_services,
    module.iam,
    module.network,
    module.cloud_nat,
    module.firewall,
  ]
}

module "fleet_memberships" {
  for_each = var.enable_fleet_registration && var.enable_gke_clusters ? toset(["main"]) : toset([])

  source = "../../modules/fleet-membership"

  project_id = var.project_id
  labels     = local.labels
  clusters   = local.gke_fleet_clusters

  depends_on = [module.project_services, module.gke_clusters]
}

module "cloud_service_mesh" {
  for_each = var.enable_cloud_service_mesh && var.enable_gke_clusters && var.enable_fleet_registration ? toset(["main"]) : toset([])

  source = "../../modules/service-mesh"

  project_id  = var.project_id
  labels      = local.labels
  memberships = module.fleet_memberships["main"].memberships

  depends_on = [module.project_services, module.fleet_memberships]
}

module "multi_cluster_ingress" {
  for_each = var.enable_multi_cluster_ingress && var.enable_gke_clusters && var.enable_fleet_registration ? toset(["main"]) : toset([])

  source = "../../modules/multi-cluster-ingress"

  project_id        = var.project_id
  labels            = local.labels
  config_membership = module.fleet_memberships["main"].memberships["primary"].name

  depends_on = [module.project_services, module.fleet_memberships]
}
