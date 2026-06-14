# OSMU Kubernetes Draft Manifests

This directory contains a draft Kubernetes deployment shape for the current OSMU prototype. It is meant as an MVP/productization starting point, not a hardened production chart.

## Files

- `namespace.yaml` - `osmu` namespace.
- `configmap.yaml` - non-secret runtime configuration.
- `secret.example.yaml` - required secret names with placeholder values. Copy it outside git-managed secrets handling before use.
- `mariadb.yaml` - MariaDB `Service` and `StatefulSet` with persistent storage.
- `minio.yaml` - MinIO `Service` and `StatefulSet` with persistent storage.
- `backend.yaml` - backend `Service` and `Deployment` with non-root security context and Prometheus scrape annotations.
- `frontend.yaml` - frontend `Service` and `Deployment`.
- `ingress.yaml` - TLS ingress draft for frontend and backend API paths.
- `networkpolicy.yaml` - backend egress and MariaDB/MinIO ingress policy draft.
- `monitoring-operator.yaml` - optional Prometheus Operator `ServiceMonitor` and `PrometheusRule` draft. Apply only after CRDs exist.
- `examples/minio-tenant-pool-expansion.example.yaml` - reference-only MinIO Operator Tenant pool expansion shape. Apply only after installing MinIO Operator and validating the schema for the target version.
- `kustomization.yaml` - resource list for non-secret manifests.
- `../k8s-overlays/osmu-dev` - development cluster overlay for namespace `osmu-dev`, static local PVs and HTTP ingress on `osmu-dev.192.168.35.60.nip.io`.

## Apply Draft

1. Build and push `osmu-backend:local` and `osmu-frontend:local`, or edit image names in the manifests.
2. Build the frontend image with a Kubernetes-appropriate API base URL, for example `VITE_API_BASE_URL=/api` when using the included ingress path split.
3. Create a real Kubernetes Secret from `secret.example.yaml` values through your secret manager.
4. Create the TLS Secret referenced by ingress, for example `osmu-tls`, through cert-manager or your cluster certificate flow.
5. Apply manifests:

```powershell
kubectl apply -f .\infra\k8s\secret.example.yaml
kubectl apply -k .\infra\k8s
```

For production, replace example secrets, connect `osmu-tls` to a real certificate issuer and rotation process, follow `dev-docs/secret-rotation-policy.md`, configure storage classes, tune resource requests/limits from load tests, confirm NetworkPolicy compatibility with the cluster CNI/ingress controller, connect Prometheus to `/actuator/prometheus` through annotations or the optional `monitoring-operator.yaml`, import the starter rules/dashboard from `infra/monitoring`, run image build/scanning for the non-root backend/frontend images, and use managed MariaDB/MinIO or an operator-backed storage deployment where appropriate.

## MinIO Capacity Expansion

The current `minio.yaml` is a single-node MVP StatefulSet and must not be scaled by only increasing `replicas`.

The selected product direction is pool-based expansion:

- Start production-like MinIO as distributed pools.
- Attach one or more PVCs to each MinIO server Pod.
- Add capacity by adding a new server pool with new Pods and PVs.
- Keep PV sizes consistent inside the same pool.
- Prefer MinIO Operator Tenant or a validated Helm chart for pool topology management.

See `dev-docs/minio-pool-expansion.md` for the OSMU storage expansion design.

## Apply `osmu-dev`

The `osmu-dev` overlay is for the `192.168.35.60` development cluster. It creates static PVs with `Retain` reclaim policy, host paths under `/var/lib/osmu-dev`, node affinity to `slave01`, schedules backend/frontend on `slave01`, and exposes HTTP ingress at `http://osmu-dev.192.168.35.60.nip.io:30080`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-osmu-dev-k8s.ps1
```

The helper creates `osmu-secret` with generated values if the secret is missing, then applies `infra/k8s-overlays/osmu-dev`. Backend and frontend images still need to exist on the cluster node or be replaced with registry images through the script parameters.
