# BigQuery Schema And Grafana Queries

Grafana reads application logs exported from Cloud Logging to BigQuery.

## Dataset

```text
PROJECT_ID.helix_sandbox_user_portal_app_logs.stdout
```

## Fields Used

| Field | Purpose |
| --- | --- |
| `timestamp` | Time axis for Grafana panels. |
| `severity` | Log severity. |
| `jsonPayload.service` | Filters `user-portal` logs. |
| `jsonPayload.event_type` | Filters HTTP request events. |
| `jsonPayload.http_request.request_path` | Groups traffic by API. |
| `jsonPayload.http_request.request_method` | Distinguishes create/update/delete routes. |
| `jsonPayload.http_request.status` | Counts errors. |
| `jsonPayload.http_request.latency_ms` | Calculates latency. |
| `jsonPayload.kubernetes.namespace` | Kubernetes namespace. |
| `jsonPayload.kubernetes.pod_name` | Kubernetes pod. |
| `jsonPayload.trace_id` | Trace correlation. |

## API Mapping

| Grafana series | Routes |
| --- | --- |
| `view-users` | `/users`, `/api/users` |
| `create-users` | `/users/new`, `POST /api/users` |
| `edit-users` | `/users/{id}/edit`, `PUT/PATCH /api/users/{id}` |
| `delete-users` | `/users/{id}/delete`, `DELETE /api/users/{id}` |

## Traffic By URL

```sql
WITH requests AS (
  SELECT
    TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
    CASE
      WHEN jsonPayload.http_request.request_path = '/users'
        OR REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/?$') THEN 'view-users'
      WHEN jsonPayload.http_request.request_path = '/users/new'
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/?$') AND jsonPayload.http_request.request_method = 'POST') THEN 'create-users'
      WHEN REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/users/[^/]+/edit$')
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/[^/]+$') AND jsonPayload.http_request.request_method IN ('PUT', 'PATCH')) THEN 'edit-users'
      WHEN REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/users/[^/]+/delete$')
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/[^/]+$') AND jsonPayload.http_request.request_method = 'DELETE') THEN 'delete-users'
      ELSE NULL
    END AS url_group
  FROM `PROJECT_ID.helix_sandbox_user_portal_app_logs.stdout`
  WHERE $__timeFilter(timestamp)
    AND jsonPayload.service = 'user-portal'
    AND jsonPayload.event_type = 'http_request'
)
SELECT
  time,
  SUM(IF(url_group = 'view-users', 1, 0)) AS `view-users`,
  SUM(IF(url_group = 'create-users', 1, 0)) AS `create-users`,
  SUM(IF(url_group = 'edit-users', 1, 0)) AS `edit-users`,
  SUM(IF(url_group = 'delete-users', 1, 0)) AS `delete-users`
FROM requests
WHERE url_group IS NOT NULL
GROUP BY time
ORDER BY time;
```

## Errors By URL

```sql
WITH requests AS (
  SELECT
    TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
    CASE
      WHEN jsonPayload.http_request.request_path = '/users'
        OR REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/?$') THEN 'view-users'
      WHEN jsonPayload.http_request.request_path = '/users/new'
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/?$') AND jsonPayload.http_request.request_method = 'POST') THEN 'create-users'
      WHEN REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/users/[^/]+/edit$')
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/[^/]+$') AND jsonPayload.http_request.request_method IN ('PUT', 'PATCH')) THEN 'edit-users'
      WHEN REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/users/[^/]+/delete$')
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/[^/]+$') AND jsonPayload.http_request.request_method = 'DELETE') THEN 'delete-users'
      ELSE NULL
    END AS url_group,
    CAST(SAFE_CAST(jsonPayload.http_request.status AS FLOAT64) AS INT64) AS status_code
  FROM `PROJECT_ID.helix_sandbox_user_portal_app_logs.stdout`
  WHERE $__timeFilter(timestamp)
    AND jsonPayload.service = 'user-portal'
    AND jsonPayload.event_type = 'http_request'
)
SELECT
  time,
  SUM(IF(url_group = 'view-users' AND status_code >= 400, 1, 0)) AS `view-users`,
  SUM(IF(url_group = 'create-users' AND status_code >= 400, 1, 0)) AS `create-users`,
  SUM(IF(url_group = 'edit-users' AND status_code >= 400, 1, 0)) AS `edit-users`,
  SUM(IF(url_group = 'delete-users' AND status_code >= 400, 1, 0)) AS `delete-users`
FROM requests
WHERE url_group IS NOT NULL
GROUP BY time
ORDER BY time;
```

## Latency By URL

```sql
WITH samples AS (
  SELECT
    TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
    CASE
      WHEN jsonPayload.http_request.request_path = '/users'
        OR REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/?$') THEN 'view-users'
      WHEN jsonPayload.http_request.request_path = '/users/new'
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/?$') AND jsonPayload.http_request.request_method = 'POST') THEN 'create-users'
      WHEN REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/users/[^/]+/edit$')
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/[^/]+$') AND jsonPayload.http_request.request_method IN ('PUT', 'PATCH')) THEN 'edit-users'
      WHEN REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/users/[^/]+/delete$')
        OR (REGEXP_CONTAINS(jsonPayload.http_request.request_path, r'^/api/users/[^/]+$') AND jsonPayload.http_request.request_method = 'DELETE') THEN 'delete-users'
      ELSE NULL
    END AS url_group,
    SAFE_CAST(jsonPayload.http_request.latency_ms AS FLOAT64) AS latency_ms
  FROM `PROJECT_ID.helix_sandbox_user_portal_app_logs.stdout`
  WHERE $__timeFilter(timestamp)
    AND jsonPayload.service = 'user-portal'
    AND jsonPayload.event_type = 'http_request'
    AND jsonPayload.http_request.latency_ms IS NOT NULL
), grouped AS (
  SELECT
    time,
    url_group,
    APPROX_QUANTILES(latency_ms, 100)[OFFSET(95)] AS p95_latency_ms
  FROM samples
  WHERE url_group IS NOT NULL
    AND latency_ms IS NOT NULL
  GROUP BY time, url_group
)
SELECT
  time,
  MAX(IF(url_group = 'view-users', p95_latency_ms, NULL)) AS `view-users`,
  MAX(IF(url_group = 'create-users', p95_latency_ms, NULL)) AS `create-users`,
  MAX(IF(url_group = 'edit-users', p95_latency_ms, NULL)) AS `edit-users`,
  MAX(IF(url_group = 'delete-users', p95_latency_ms, NULL)) AS `delete-users`
FROM grouped
GROUP BY time
ORDER BY time;
```

## Validation Query

```sql
SELECT
  timestamp,
  severity,
  jsonPayload.message AS message,
  jsonPayload.event_type AS event_type,
  jsonPayload.http_request.request_path AS request_path,
  jsonPayload.http_request.status AS status,
  jsonPayload.http_request.latency_ms AS latency_ms
FROM `PROJECT_ID.helix_sandbox_user_portal_app_logs.stdout`
ORDER BY timestamp DESC
LIMIT 20;
```
