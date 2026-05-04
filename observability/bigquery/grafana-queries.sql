-- Grafana BigQuery query reference.
-- Full field notes: docs/bigquery-grafana.md

-- Traffic by URL.
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
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
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

-- Errors by URL.
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
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
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

-- Latency by URL.
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
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
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
