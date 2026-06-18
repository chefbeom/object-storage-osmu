# OSMU Monitoring Draft

This directory contains productization-ready monitoring starter artifacts for the OSMU prototype.

## Files

- `prometheus-rules.yaml` - Prometheus alert rule draft for backend availability, error rate, latency, retention failures, share link cleanup failures, data-flow failure/cancel/egress/bucket anomaly signals, backup readiness gaps, and backup CronJob failures or stale successful runs.
- `grafana-dashboard-osmu.json` - Grafana dashboard draft for backend traffic, latency, JVM memory, storage operations, retention, data-flow operations/bytes, and backup readiness notes.
- `../k8s/monitoring-operator.yaml` - optional Prometheus Operator `ServiceMonitor` and `PrometheusRule` draft.
- `../helm/osmu/templates/monitoring-operator.yaml` - optional Helm template for Prometheus Operator resources.

## Usage

1. Scrape the backend `/actuator/prometheus` endpoint.
2. Load `prometheus-rules.yaml` into Prometheus or convert it into a `PrometheusRule` resource when using Prometheus Operator.
3. Import `grafana-dashboard-osmu.json` into Grafana.
4. Replace draft job labels with the target environment's scrape labels if needed.

Prometheus Operator:

- Plain Kubernetes: apply `infra/k8s/monitoring-operator.yaml` only after the `monitoring.coreos.com/v1` CRDs are installed. It is intentionally not included in `infra/k8s/kustomization.yaml`.
- Helm: set `monitoring.operator.enabled=true` when the target cluster has Prometheus Operator CRDs and the Prometheus instance selects the configured `release` label.

## Scope

These files are alert/dashboard contracts for MVP pilot preparation. They do not prove production SLOs until connected to a running Prometheus/Grafana stack in the target environment.
