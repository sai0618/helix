# User Data

MySQL initialization data for the Helix user registration app.

The application uses two tables:

- `user_credentials`: login identity data with username and hashed password.
- `user_info`: registered user profile data managed through the UI and REST API.

## Initialize Local MySQL

```bash
mysql -h 127.0.0.1 -u helix_app -p helix_users < init.sql
```

All sample users use the initial password `ChangeMe123!`.

## Cloud SQL

Terraform uploads `init.sql` to a private GCS bucket when Cloud SQL is enabled. If `enable_cloud_sql_import = true`, Terraform runs `gcloud sql import sql` to initialize the schema and seed rows.
