# User Portal

Flask and Jinja2 application that serves both the user registration UI and REST API.

The app persists data in MySQL using two tables initialized by `apps/user-data`:

- `user_credentials`
- `user_info`

## Environment

- `APP_LOGIN_USERNAME`: App login username. Defaults to `admin`.
- `APP_LOGIN_PASSWORD`: App login password for local development.
- `APP_LOGIN_PASSWORD_HASH`: Werkzeug-compatible app login password hash.
- `APP_LOGIN_CREDENTIALS_JSON`: JSON payload for app login credentials.
- `APP_LOGIN_CREDENTIALS_FILE`: Mounted JSON file for app login credentials. Defaults to `/var/secrets/helix/app-login-credentials.json`.
- `MYSQL_CREDENTIALS_JSON`: JSON payload for MySQL credentials.
- `MYSQL_CREDENTIALS_FILE`: Mounted JSON file for MySQL credentials. Defaults to `/var/secrets/helix/mysql-credentials.json`.
- `MYSQL_HOST`: MySQL host. Defaults to `127.0.0.1`.
- `MYSQL_PORT`: MySQL port. Defaults to `3306`.
- `MYSQL_DATABASE`: MySQL database. Defaults to `helix_users`.
- `MYSQL_USER`: MySQL user. Defaults to `helix_app`.
- `MYSQL_PASSWORD`: MySQL password. Defaults to `helix-dev-password`.
- `MYSQL_UNIX_SOCKET`: Optional Cloud SQL Unix socket path.
- `PORT`: Local UI port. Defaults to `8080`.

## Run

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python app.py
```

Open `http://localhost:8080`.

The GKE Helm deployment should use Secret Manager JSON files with these shapes:

```json
{"username":"admin","password_hash":"scrypt:..."}
```

```json
{"username":"helix_app","password":"mysql-password","database":"helix_users","host":"helix-mysql","port":"3306"}
```
