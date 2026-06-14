# OSMU Operation and Monitoring

This document defines the current operation and monitoring baseline for the OSMU prototype.

## 1. Goals

- Detect backend, metadata, and object storage health issues quickly.
- Trace role-based access and important storage changes.
- Watch quota, bucket, and object growth.
- Expose backup/restore readiness honestly to operators.
- Detect security and authentication failure spikes.

## 2. Health And Readiness APIs

Required endpoints:

- `GET /api/health`
- `GET /api/database/health`
- `GET /api/storage/health`
- `GET /api/admin/system/status`
- `GET /api/admin/backup/status`
- `GET /actuator/prometheus`

`/api/admin/backup/status` returns `DRILL_PENDING` in lightweight demo mode and lists durable pilot gaps in `pendingGates`.
`/actuator/prometheus` is the Prometheus scrape endpoint.

## 3. Logs

Application logs should include:

- requestId
- method
- path
- status
- latency
- userId
- errorCode

Application logs must not include:

- password
- secretKey
- token
- Authorization header

## 4. Audit Log

Audit targets:

- login success/failure
- user create/status update
- organization create/delete
- bucket create/delete/permission/tag/lifecycle changes
- object upload/download/delete/restore/purge
- access key create/revoke
- retention/lifecycle policy changes
- major S3-compatible API operations

## 5. Metrics

Backend:

- request count
- request latency
- error count
- JVM memory/GC metrics
- bucket/object operation count
- multipart cleanup success/failure count
- object retention purge success/failure count
- object version retention purge success/failure count

MariaDB:

- connection count
- query latency
- storage usage
- replication status optional

MinIO:

- disk usage
- bucket usage
- object count
- request count
- error count
- node health

## 6. Dashboard

MVP dashboard areas:

- backend up/down
- MariaDB metadata up/down
- MinIO object storage up/down
- total quota/used/bucket/object count
- admin quota policy list with target used/quota/remaining bytes
- admin quota policy change history with create/update/delete actor, quota delta, and optional reason
- password/IP-restricted object share link create/public download/revoke/manual cleanup/scheduled cleanup audit trail with global share policy save events, admin share analytics, download count, last-access visibility, and cleanup failure metric
- object retention status
- lifecycle policy/conflict/dry-run
- backup readiness status
- audit log filter/export

Product dashboard areas:

- organization usage
- bucket usage
- user traffic
- API latency p95/p99
- error trend
- backup job history
- restore drill history
- certificate/secret rotation history

## 7. Alerts

Alert conditions:

- backend down
- MariaDB down
- MinIO down
- disk usage >= 80 percent
- disk usage >= 90 percent
- API 5xx error spike
- API latency p95 above threshold
- backup failure
- restore drill failure
- authentication failure spike
- certificate expiry threshold reached

## 8. Tools

MVP:

- Spring Boot Actuator
- Actuator Prometheus endpoint
- Prometheus rule draft under `infra/monitoring`
- Grafana dashboard draft under `infra/monitoring`
- Optional Prometheus Operator draft under `infra/k8s` and `infra/helm/osmu`
- MinIO Console
- Application logs
- Admin dashboard

Product:

- Prometheus
- Grafana
- AlertManager
- Loki optional
- Secret manager audit logs

## 9. Object Lifecycle Operations

- Admin dashboard lists prefix/tag lifecycle rules and supports save/delete.
- Lower priority number runs first; use distinct priorities for overlapping rule scopes.
- Conflict Report should be checked after adding rules with broad prefixes or partial tag filters.
- Use Dry run before enabling or tightening a rule to preview candidate count and bytes.
- S3 Lifecycle XML import should be reviewed with Conflict Report and Dry run before enabling aggressive retention.
- Bucket lifecycle API should be used for S3-compatible bucket-scoped policies; confirm imported rules carry the expected `bucketName`.
- Operators should monitor purge counters after rule changes to confirm rule scope.
- MariaDB mode requires `object_lifecycle_rules` migration before rules persist across restart.

## 10. Backup Restore Operations

- `dev-docs/backup-restore-drill.md` is the current runbook.
- MVP pilot targets RPO 24h and RTO 4h.
- Lightweight demo mode does not prove durable backup/restore.
- Durable pilot requires MariaDB dump restore, MinIO object restore, object count/byte reconciliation, API smoke, and S3 client smoke.
- `GET /api/admin/backup/status` exposes current readiness and pending gates in the admin portal.

## 11. Prometheus And Grafana

- Backend exposes `/actuator/prometheus`.
- Kubernetes backend Service includes `prometheus.io/scrape=true`, `prometheus.io/path=/actuator/prometheus`, and `prometheus.io/port=8080`.
- Helm enables the same scrape annotations through `backend.metrics`.
- `infra/monitoring/prometheus-rules.yaml` defines starter alerts.
- `infra/monitoring/grafana-dashboard-osmu.json` defines a starter overview dashboard.
- `infra/k8s/monitoring-operator.yaml` defines optional `ServiceMonitor` and `PrometheusRule` resources.
- `infra/helm/osmu/templates/monitoring-operator.yaml` renders the same optional resources when `monitoring.operator.enabled=true`.
- Product deployment can replace annotations with `ServiceMonitor` when Prometheus Operator is used, but only after `monitoring.coreos.com/v1` CRDs are installed.
