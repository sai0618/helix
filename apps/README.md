# Helix Apps

This folder contains the application units for the Helix platform.

## Applications

- `user-portal`: Flask and Jinja2 app that serves the user registration UI and REST API.
- `user-data`: MySQL initialization SQL and Docker image for the application database.

The previous standalone `user-api` service has been merged into `user-portal`.

## Local Startup Order

Create the MySQL schema and seed data:

```bash
cd apps/user-data
mysql -h 127.0.0.1 -u helix_app -p helix_users < init.sql
```

Start the merged web/API app:

```bash
cd apps/user-portal
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python app.py
```

The UI is available at `http://localhost:8080`.

REST endpoints are served by the same app under `/api/users`.

## Container Images

The Google Cloud Sandbox setup builds and pushes both app images automatically:

```bash
scripts/build_new_sandbox_images.sh --mode docker
```

Images are pushed to:

```text
REGION-docker.pkg.dev/PROJECT_ID/helix-sandbox-docker/user-portal:VERSION
REGION-docker.pkg.dev/PROJECT_ID/helix-sandbox-docker/user-data:VERSION
```
