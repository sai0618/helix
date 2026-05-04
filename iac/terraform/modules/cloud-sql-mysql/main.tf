data "google_project" "current" {
  project_id = var.project_id
}

resource "google_sql_database_instance" "mysql" {
  project          = var.project_id
  name             = var.instance_name
  region           = var.region
  database_version = "MYSQL_8_0"

  deletion_protection = false

  settings {
    tier              = var.tier
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = false
    user_labels       = var.labels

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.private_network
    }
  }
}

resource "google_sql_database" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.mysql.name
  name     = var.database_name
  charset  = "utf8mb4"
}

resource "google_sql_user" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.mysql.name
  name     = var.database_user
  password = var.database_password
}

resource "google_storage_bucket" "init_sql" {
  project                     = var.project_id
  name                        = var.init_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  versioning {
    enabled = true
  }

  labels = var.labels
}

resource "google_storage_bucket_object" "init_sql" {
  name   = "mysql/init.sql"
  bucket = google_storage_bucket.init_sql.name
  source = var.init_sql_source_path
}

resource "google_storage_bucket_iam_member" "cloud_sql_import_reader" {
  count = var.enable_sql_import ? 1 : 0

  bucket = google_storage_bucket.init_sql.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}

resource "terraform_data" "import_sql" {
  count = var.enable_sql_import ? 1 : 0

  triggers_replace = {
    database     = google_sql_database.app.name
    instance     = google_sql_database_instance.mysql.name
    init_sql_md5 = filemd5(var.init_sql_source_path)
    object       = google_storage_bucket_object.init_sql.md5hash
  }

  provisioner "local-exec" {
    command = join(" ", [
      "gcloud sql import sql",
      google_sql_database_instance.mysql.name,
      "gs://${google_storage_bucket.init_sql.name}/${google_storage_bucket_object.init_sql.name}",
      "--database=${google_sql_database.app.name}",
      "--project=${var.project_id}",
      "--quiet",
    ])
  }

  depends_on = [
    google_sql_user.app,
    google_storage_bucket_iam_member.cloud_sql_import_reader[0],
  ]
}
