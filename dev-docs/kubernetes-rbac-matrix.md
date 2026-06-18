# OSMU Kubernetes RBAC Matrix

This document defines the Kubernetes ServiceAccount, token automount, and RBAC boundary for OSMU deployments. Application-level `ADMIN` / `ORG_ADMIN` / `USER` permissions are tracked in `iam-rbac-matrix.md`; this file covers only Kubernetes cluster permissions.

## 1. Principles

- Workloads that do not need the Kubernetes API use dedicated ServiceAccounts with token automount disabled.
- The Kubernetes `default` ServiceAccount is not used by OSMU workloads.
- Backend, frontend, MariaDB, MinIO, backup, and restore workloads do not receive application Kubernetes API permissions.
- Storage Expansion kubectl runner uses a separate namespace-scoped `osmu-storage-expansion-runner` ServiceAccount, Role, and RoleBinding.
- The runner role is limited to `Tenant/osmu-minio` patch/update and legacy `StatefulSet/osmu-minio` rollback/status operations. It grants no Secret read, no Pod exec, no create/delete, and no cluster-scoped RBAC.
- Helm upgrade/rollback and GitOps PR runner paths should use an external GitOps/CI identity unless a separately reviewed chart-admin role is added.

## 2. Workload Matrix

| Workload | ServiceAccount | Automount Token | Kubernetes Role/Binding | Reason |
| --- | --- | --- | --- | --- |
| Backend Deployment | `osmu-backend` | `false` | None | REST/S3 control plane needs DB/MinIO network access, not Kubernetes API access. |
| Frontend Deployment | `osmu-frontend` | `false` | None | Static UI serving does not need Kubernetes API access. |
| MariaDB StatefulSet | `osmu-mariadb` | `false` | None | Database process does not need Kubernetes API access. |
| MinIO StatefulSet | `osmu-minio` | `false` | None | MVP object storage process does not need Kubernetes API access. |
| Backup CronJobs | `osmu-backup` | `false` | None | MariaDB/MinIO network backup only. |
| Restore Job example | `osmu-backup` | `false` | None | Manual restore example does not need Kubernetes API access. |
| Storage Expansion kubectl runner | `osmu-storage-expansion-runner` | `false` by default. Runner-enabled Pod must opt in explicitly. | `Role/RoleBinding` named `osmu-storage-expansion-runner` | Allows reviewed in-cluster kubectl diff/apply/rollback without granting app pods Kubernetes API access. |
| Prometheus Operator draft | External operator SA | External | External | Managed by the installed Prometheus Operator. |
| MinIO Operator Tenant mode | MinIO Operator managed | Operator managed | Operator managed | Operator installation and permissions are a separate operations responsibility. |

## 3. Manifest Contract

Raw Kubernetes manifests:

- `infra/k8s/serviceaccount.yaml` defines `osmu-backend`, `osmu-frontend`, `osmu-mariadb`, and `osmu-minio` with `automountServiceAccountToken: false`.
- `infra/k8s/storage-expansion-rbac.yaml` defines `osmu-storage-expansion-runner` ServiceAccount, Role, and RoleBinding.
- `infra/k8s/backup.yaml` defines `osmu-backup` with `automountServiceAccountToken: false`.
- `infra/k8s/backend.yaml`, `frontend.yaml`, `mariadb.yaml`, and `minio.yaml` set explicit `serviceAccountName` and Pod-level `automountServiceAccountToken: false`.
- `infra/k8s/examples/restore-from-backup.example.yaml` uses `osmu-backup` and Pod-level token automount disabled.
- `infra/k8s/kustomization.yaml` includes `serviceaccount.yaml` and `storage-expansion-rbac.yaml`.

Helm chart:

- `infra/helm/osmu/templates/serviceaccount.yaml` defines app/data ServiceAccounts.
- `infra/helm/osmu/templates/storage-expansion-rbac.yaml` optionally renders storage expansion runner RBAC when `storageExpansion.runner.rbac.enabled=true`.
- `infra/helm/osmu/templates/backup.yaml` defines backup ServiceAccount.
- Backend, frontend, MariaDB, and MinIO templates set explicit ServiceAccount and disabled token automount.

## 4. Storage Expansion Runner Permission Boundary

Allowed Kubernetes direct runner operations:

- `get`, `patch`, `update` on `minio.min.io` `tenants` with `resourceNames: [osmu-minio]`.
- `get`, `patch`, `update` on `apps` `statefulsets` with `resourceNames: [osmu-minio]`.
- `get` on `apps` `statefulsets/status` with `resourceNames: [osmu-minio]`.

Explicitly forbidden in this draft:

- `ClusterRole` and `ClusterRoleBinding`.
- Secret read or write.
- Pod exec or log access.
- Generic pod/job creation.
- Resource delete.
- Tenant create. Expansion should patch the reviewed `Tenant/osmu-minio`; creating a new Tenant requires a separate approval path.

Helm upgrade/rollback is broader than this runner role because Helm normally needs release Secret/ConfigMap and chart-managed resource permissions. Use external GitOps/CI identity for that path until a dedicated chart-admin role is reviewed.

Multi-tenant customer clusters may require namespace-scoped Roles for additional resources. Those permissions must be explicit and verified before production.

## 5. Verification

- `scripts/verify-kubernetes-rbac-matrix.ps1`
- `scripts/verify-k8s-manifests.ps1`
- `scripts/verify-helm-chart.ps1`
- `scripts/verify-storage-expansion-rbac-auth.ps1 -Namespace <namespace>` for live `kubectl auth can-i` evidence after applying the runner RBAC manifest.
- `scripts/verify-storage-expansion-rbac-auth.ps1 -PlanOnly` for local command-plan review without a cluster.
- `scripts/verify-storage-expansion-server-dry-run.ps1 -Namespace <namespace>` for live MinIO Tenant CRD, existing Tenant, and `kubectl apply --server-side --dry-run=server` evidence.
- `scripts/verify-storage-expansion-server-dry-run.ps1 -PlanOnly` for local dry-run command-plan review without a cluster.
- Optional render check: `kubectl kustomize infra/k8s`
