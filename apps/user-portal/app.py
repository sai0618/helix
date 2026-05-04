from __future__ import annotations

import os
import json
import logging
import sys
import time
import uuid
from functools import wraps
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

import pymysql
from flask import Flask, flash, g, jsonify, redirect, render_template, request, session, url_for
from opentelemetry import trace as otel_trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.pymysql import PyMySQLInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from pymysql.cursors import DictCursor
from werkzeug.exceptions import HTTPException
from werkzeug.security import check_password_hash, generate_password_hash


app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-only-change-me")


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, timezone.utc).isoformat(),
            "severity": record.levelname,
            "message": record.getMessage(),
            "service": os.getenv("SERVICE_NAME", "user-portal"),
            "environment": os.getenv("APP_ENV", "sandbox"),
            "version": os.getenv("APP_VERSION", "unknown"),
            "logger": record.name,
        }

        for key, value in getattr(record, "structured_fields", {}).items():
            if value is not None:
                payload[key] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, default=str, separators=(",", ":"))


def configure_logging() -> logging.Logger:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonLogFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers = [handler]
    root_logger.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())

    logging.getLogger("werkzeug").handlers = []
    logging.getLogger("werkzeug").propagate = True
    logging.getLogger("gunicorn.error").handlers = []
    logging.getLogger("gunicorn.error").propagate = True

    return logging.getLogger("user_portal")


logger = configure_logging()


def env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name, "").strip().lower()
    if not value:
        return default
    return value in {"1", "true", "yes", "y", "on"}


def cloud_trace_project_id() -> str | None:
    return (
        os.getenv("OTEL_EXPORTER_GCP_TRACE_PROJECT_ID")
        or os.getenv("GOOGLE_CLOUD_PROJECT")
        or os.getenv("GCP_PROJECT")
    )


def service_resource() -> Resource:
    return Resource.create(
        {
            "service.name": os.getenv("SERVICE_NAME", "user-portal"),
            "service.version": os.getenv("APP_VERSION", "unknown"),
            "deployment.environment.name": os.getenv("APP_ENV", "sandbox"),
            "k8s.namespace.name": os.getenv("POD_NAMESPACE", ""),
            "k8s.pod.name": os.getenv("POD_NAME", ""),
            "k8s.node.name": os.getenv("NODE_NAME", ""),
        }
    )


def configure_tracing(flask_app: Flask):
    if not env_bool("OTEL_TRACES_ENABLED", True):
        logger.info(
            "opentelemetry tracing disabled",
            extra={"structured_fields": {"event_type": "otel_tracing_disabled"}},
        )
        return otel_trace.get_tracer("user_portal")

    try:
        sample_rate = float(os.getenv("OTEL_TRACES_SAMPLE_RATE", "1.0"))
        sample_rate = min(max(sample_rate, 0.0), 1.0)
        project_id = cloud_trace_project_id()
        provider = TracerProvider(
            resource=service_resource(),
            sampler=ParentBased(TraceIdRatioBased(sample_rate)),
        )
        exporter = (
            CloudTraceSpanExporter(project_id=project_id)
            if project_id
            else CloudTraceSpanExporter()
        )
        provider.add_span_processor(BatchSpanProcessor(exporter))
        otel_trace.set_tracer_provider(provider)

        FlaskInstrumentor().instrument_app(flask_app)
        PyMySQLInstrumentor().instrument()
        logger.info(
            "opentelemetry tracing configured",
            extra={
                "structured_fields": {
                    "event_type": "otel_tracing_configured",
                    "trace_exporter": "google_cloud_trace",
                    "trace_project_id": project_id,
                    "sample_rate": sample_rate,
                }
            },
        )
    except Exception:
        logger.exception(
            "opentelemetry tracing setup failed",
            extra={"structured_fields": {"event_type": "otel_tracing_setup_failed"}},
        )

    return otel_trace.get_tracer("user_portal")


tracer = configure_tracing(app)


def active_trace_fields() -> dict[str, Any]:
    span = otel_trace.get_current_span()
    context = span.get_span_context() if span else None
    if context and context.is_valid:
        trace_id = f"{context.trace_id:032x}"
        span_id = f"{context.span_id:016x}"
        fields = {
            "trace_id": trace_id,
            "span_id": span_id,
            "trace_sampled": bool(context.trace_flags.sampled),
        }
        project_id = cloud_trace_project_id()
        if project_id:
            fields["logging.googleapis.com/trace"] = f"projects/{project_id}/traces/{trace_id}"
            fields["logging.googleapis.com/spanId"] = span_id
            fields["logging.googleapis.com/trace_sampled"] = bool(context.trace_flags.sampled)
        return fields

    header_trace_id = request.headers.get("X-Cloud-Trace-Context", "").split("/", 1)[0] or None
    return {"trace_id": header_trace_id}


def request_context_fields(status_code: int | None = None) -> dict[str, Any]:
    request_id = getattr(g, "request_id", None)
    duration_ms = None
    if hasattr(g, "request_started_at"):
        duration_ms = round((time.perf_counter() - g.request_started_at) * 1000, 2)

    fields = {
        "event_type": "http_request",
        "request_id": request_id,
        "http_request": {
            "request_method": request.method,
            "request_url": request.url,
            "request_path": request.path,
            "remote_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
            "user_agent": request.headers.get("User-Agent"),
            "status": status_code,
            "latency_ms": duration_ms,
            "referer": request.headers.get("Referer"),
        },
        "kubernetes": {
            "namespace": os.getenv("POD_NAMESPACE"),
            "pod_name": os.getenv("POD_NAME"),
            "node_name": os.getenv("NODE_NAME"),
        },
    }
    fields.update(active_trace_fields())

    if session.get("username"):
        fields["actor"] = {"username": session.get("username")}

    return fields


def log_event(
    message: str,
    *,
    severity: int = logging.INFO,
    event_type: str,
    **fields: Any,
) -> None:
    structured_fields = {
        "event_type": event_type,
        "request_id": getattr(g, "request_id", None),
        "kubernetes": {
            "namespace": os.getenv("POD_NAMESPACE"),
            "pod_name": os.getenv("POD_NAME"),
            "node_name": os.getenv("NODE_NAME"),
        },
        **fields,
    }
    structured_fields.update(active_trace_fields())
    if session.get("username"):
        structured_fields["actor"] = {"username": session.get("username")}

    logger.log(severity, message, extra={"structured_fields": structured_fields})


@app.before_request
def start_request_logging():
    g.request_started_at = time.perf_counter()
    g.request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())


@app.after_request
def log_request(response):
    severity = logging.INFO if response.status_code < 500 else logging.ERROR
    logger.log(
        severity,
        "request completed",
        extra={"structured_fields": request_context_fields(response.status_code)},
    )
    response.headers["X-Request-ID"] = g.request_id
    return response


@app.errorhandler(Exception)
def log_unhandled_exception(exc: Exception):
    if isinstance(exc, HTTPException):
        return exc

    logger.exception(
        "unhandled exception",
        extra={"structured_fields": request_context_fields(500)},
    )
    return {"detail": "Internal server error", "request_id": getattr(g, "request_id", None)}, 500


def load_json_secret(env_var: str, file_env_var: str, default_file_path: str) -> dict[str, Any]:
    raw_value = os.getenv(env_var, "").strip()
    if raw_value:
        return json.loads(raw_value)

    file_path = os.getenv(file_env_var, default_file_path).strip()
    if not file_path or not os.path.exists(file_path):
        return {}

    with open(file_path, encoding="utf-8") as secret_file:
        return json.load(secret_file)


def app_login_config() -> dict[str, str]:
    secret = load_json_secret(
        "APP_LOGIN_CREDENTIALS_JSON",
        "APP_LOGIN_CREDENTIALS_FILE",
        "/var/secrets/helix/app-login-credentials.json",
    )
    return {
        "username": str(secret.get("username") or os.getenv("APP_LOGIN_USERNAME", "admin")),
        "password": str(secret.get("password") or os.getenv("APP_LOGIN_PASSWORD", "")),
        "password_hash": str(
            secret.get("password_hash") or os.getenv("APP_LOGIN_PASSWORD_HASH", "")
        ),
    }


def authenticate_app_user(username: str, password: str) -> bool:
    credentials = app_login_config()
    if username != credentials["username"]:
        return False

    if credentials["password_hash"]:
        return check_password_hash(credentials["password_hash"], password)

    return bool(credentials["password"]) and password == credentials["password"]


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if session.get("authenticated"):
            return view(*args, **kwargs)

        if request.path.startswith("/api/"):
            return {"detail": "Authentication required"}, 401

        return redirect(url_for("login", next=request.full_path))

    return wrapped_view


def safe_redirect_target(target: str | None) -> str | None:
    if not target:
        return None

    parsed = urlparse(target)
    if parsed.scheme or parsed.netloc:
        return None

    return target


def db_config() -> dict[str, Any]:
    secret = load_json_secret(
        "MYSQL_CREDENTIALS_JSON",
        "MYSQL_CREDENTIALS_FILE",
        "/var/secrets/helix/mysql-credentials.json",
    )
    unix_socket = os.getenv("MYSQL_UNIX_SOCKET", "").strip()
    config: dict[str, Any] = {
        "user": secret.get("username") or os.getenv("MYSQL_USER", "helix_app"),
        "password": secret.get("password") or os.getenv("MYSQL_PASSWORD", "helix-dev-password"),
        "database": secret.get("database") or os.getenv("MYSQL_DATABASE", "helix_users"),
        "cursorclass": DictCursor,
        "autocommit": False,
    }

    if unix_socket:
        config["unix_socket"] = unix_socket
    else:
        config["host"] = secret.get("host") or os.getenv("MYSQL_HOST", "127.0.0.1")
        config["port"] = int(secret.get("port") or os.getenv("MYSQL_PORT", "3306"))

    return config


def get_connection():
    return pymysql.connect(**db_config())


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def user_payload(form_data: Any) -> dict[str, Any]:
    return {
        "username": form_data.get("username", "").strip(),
        "password": form_data.get("password", ""),
        "first_name": form_data.get("first_name", "").strip(),
        "last_name": form_data.get("last_name", "").strip(),
        "email": form_data.get("email", "").strip(),
        "role": form_data.get("role", "user").strip() or "user",
        "active": form_data.get("active") == "on",
    }


def row_to_user(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": row["id"],
        "username": row["username"],
        "first_name": row["first_name"],
        "last_name": row["last_name"],
        "email": row["email"],
        "role": row["role"],
        "active": bool(row["active"]),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
    }


def list_registered_users() -> list[dict[str, Any]]:
    with tracer.start_as_current_span("users.list"):
        return _list_registered_users()


def _list_registered_users() -> list[dict[str, Any]]:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT ui.id, uc.username, ui.first_name, ui.last_name, ui.email,
                       ui.role, ui.active, ui.created_at, ui.updated_at
                FROM user_info ui
                JOIN user_credentials uc ON uc.user_id = ui.id
                ORDER BY ui.email
                """
            )
            return [row_to_user(row) for row in cursor.fetchall()]


def get_registered_user(user_id: str) -> dict[str, Any] | None:
    with tracer.start_as_current_span("users.get") as span:
        span.set_attribute("app.user.id", user_id)
        return _get_registered_user(user_id)


def _get_registered_user(user_id: str) -> dict[str, Any] | None:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT ui.id, uc.username, ui.first_name, ui.last_name, ui.email,
                       ui.role, ui.active, ui.created_at, ui.updated_at
                FROM user_info ui
                JOIN user_credentials uc ON uc.user_id = ui.id
                WHERE ui.id = %s
                """,
                (user_id,),
            )
            row = cursor.fetchone()
            return row_to_user(row) if row else None


def create_registered_user(payload: dict[str, Any]) -> dict[str, Any]:
    with tracer.start_as_current_span("users.create") as span:
        span.set_attribute("app.user.email", payload.get("email", ""))
        span.set_attribute("app.user.role", payload.get("role", ""))
        return _create_registered_user(payload)


def _create_registered_user(payload: dict[str, Any]) -> dict[str, Any]:
    now = utc_now()
    user_id = str(uuid.uuid4())
    password = payload.get("password") or "ChangeMe123!"
    password_hash = generate_password_hash(password)

    with get_connection() as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO user_info
                      (id, first_name, last_name, email, role, active, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        user_id,
                        payload["first_name"],
                        payload["last_name"],
                        payload["email"],
                        payload["role"],
                        payload["active"],
                        now,
                        now,
                    ),
                )
                cursor.execute(
                    """
                    INSERT INTO user_credentials
                      (user_id, username, password_hash, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (user_id, payload["username"], password_hash, now, now),
                )
            connection.commit()
        except Exception:
            connection.rollback()
            raise

    created = get_registered_user(user_id)
    if created is None:
        raise RuntimeError("Created user could not be loaded")
    return created


def update_registered_user(user_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
    with tracer.start_as_current_span("users.update") as span:
        span.set_attribute("app.user.id", user_id)
        span.set_attribute("app.user.email", payload.get("email", ""))
        return _update_registered_user(user_id, payload)


def _update_registered_user(user_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
    now = utc_now()
    with get_connection() as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE user_info
                    SET first_name = %s, last_name = %s, email = %s,
                        role = %s, active = %s, updated_at = %s
                    WHERE id = %s
                    """,
                    (
                        payload["first_name"],
                        payload["last_name"],
                        payload["email"],
                        payload["role"],
                        payload["active"],
                        now,
                        user_id,
                    ),
                )
                if cursor.rowcount == 0:
                    connection.rollback()
                    return None

                if payload.get("username"):
                    cursor.execute(
                        """
                        UPDATE user_credentials
                        SET username = %s, updated_at = %s
                        WHERE user_id = %s
                        """,
                        (payload["username"], now, user_id),
                    )

                if payload.get("password"):
                    cursor.execute(
                        """
                        UPDATE user_credentials
                        SET password_hash = %s, updated_at = %s
                        WHERE user_id = %s
                        """,
                        (generate_password_hash(payload["password"]), now, user_id),
                    )
            connection.commit()
        except Exception:
            connection.rollback()
            raise

    return get_registered_user(user_id)


def delete_registered_user(user_id: str) -> bool:
    with tracer.start_as_current_span("users.delete") as span:
        span.set_attribute("app.user.id", user_id)
        return _delete_registered_user(user_id)


def _delete_registered_user(user_id: str) -> bool:
    with get_connection() as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM user_info WHERE id = %s", (user_id,))
                deleted = cursor.rowcount > 0
            connection.commit()
            return deleted
        except Exception:
            connection.rollback()
            raise


@app.get("/healthz")
def healthz():
    try:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
        log_event("health check succeeded", event_type="health_check", database="mysql")
        return {"status": "ok", "database": "mysql"}
    except Exception as exc:
        log_event(
            "health check failed",
            severity=logging.ERROR,
            event_type="health_check",
            database="mysql",
            error=str(exc),
        )
        return {"status": "error", "detail": str(exc)}, 503


@app.get("/")
def index():
    return redirect(url_for("list_users"))


@app.get("/api/users")
@login_required
def api_list_users():
    return jsonify(list_registered_users())


@app.post("/api/users")
@login_required
def api_create_user():
    user = create_registered_user(request.get_json(force=True))
    log_event("user created through api", event_type="user_created", user_id=user["id"])
    return jsonify(user), 201


@app.get("/api/users/<user_id>")
@login_required
def api_get_user(user_id: str):
    user = get_registered_user(user_id)
    if user is None:
        return {"detail": "User not found"}, 404
    return jsonify(user)


@app.put("/api/users/<user_id>")
@login_required
def api_update_user(user_id: str):
    user = update_registered_user(user_id, request.get_json(force=True))
    if user is None:
        return {"detail": "User not found"}, 404
    log_event("user updated through api", event_type="user_updated", user_id=user_id)
    return jsonify(user)


@app.delete("/api/users/<user_id>")
@login_required
def api_delete_user(user_id: str):
    if not delete_registered_user(user_id):
        return {"detail": "User not found"}, 404
    log_event("user deleted through api", event_type="user_deleted", user_id=user_id)
    return "", 204


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        if authenticate_app_user(username, password):
            session.clear()
            session["authenticated"] = True
            session["username"] = username
            log_event("login succeeded", event_type="login_succeeded", actor={"username": username})
            return redirect(safe_redirect_target(request.args.get("next")) or url_for("list_users"))

        log_event(
            "login failed",
            severity=logging.WARNING,
            event_type="login_failed",
            actor={"username": username},
        )
        flash("Invalid username or password.", "error")

    return render_template("login.html")


@app.post("/logout")
def logout():
    if session.get("username"):
        log_event("logout", event_type="logout", actor={"username": session.get("username")})
    session.clear()
    return redirect(url_for("login"))


@app.get("/users")
@login_required
def list_users():
    try:
        users = list_registered_users()
    except Exception as exc:
        users = []
        flash(f"Could not load users from MySQL: {exc}", "error")

    return render_template("users/list.html", users=users)


@app.route("/users/new", methods=["GET", "POST"])
@login_required
def add_user():
    if request.method == "POST":
        payload = user_payload(request.form)
        try:
            create_registered_user(payload)
            log_event("user created through ui", event_type="user_created", user_email=payload["email"])
            flash("User created.", "success")
            return redirect(url_for("list_users"))
        except Exception as exc:
            flash(str(exc), "error")
            return render_template("users/form.html", user=payload, mode="add")

    return render_template("users/form.html", user={}, mode="add")


@app.get("/users/<user_id>")
@login_required
def view_user(user_id: str):
    try:
        user = get_registered_user(user_id)
    except Exception as exc:
        flash(str(exc), "error")
        return redirect(url_for("list_users"))

    if user is None:
        flash("User not found.", "error")
        return redirect(url_for("list_users"))

    return render_template("users/detail.html", user=user)


@app.route("/users/<user_id>/edit", methods=["GET", "POST"])
@login_required
def edit_user(user_id: str):
    if request.method == "POST":
        payload = user_payload(request.form)
        try:
            user = update_registered_user(user_id, payload)
            if user is None:
                flash("User not found.", "error")
                return redirect(url_for("list_users"))
            log_event("user updated through ui", event_type="user_updated", user_id=user_id)
            flash("User updated.", "success")
            return redirect(url_for("view_user", user_id=user_id))
        except Exception as exc:
            payload["id"] = user_id
            flash(str(exc), "error")
            return render_template("users/form.html", user=payload, mode="edit")

    try:
        user = get_registered_user(user_id)
    except Exception as exc:
        flash(str(exc), "error")
        return redirect(url_for("list_users"))

    if user is None:
        flash("User not found.", "error")
        return redirect(url_for("list_users"))

    return render_template("users/form.html", user=user, mode="edit")


@app.post("/users/<user_id>/delete")
@login_required
def delete_user(user_id: str):
    try:
        if delete_registered_user(user_id):
            log_event("user deleted through ui", event_type="user_deleted", user_id=user_id)
            flash("User deleted.", "success")
        else:
            flash("User not found.", "error")
    except Exception as exc:
        flash(str(exc), "error")

    return redirect(url_for("list_users"))


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=True)
