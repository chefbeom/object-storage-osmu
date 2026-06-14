# OSMU Helm Chart Draft

This chart is a productization draft for the OSMU prototype. It mirrors the
plain Kubernetes manifests under `infra/k8s` and keeps customer/env-specific
values in `values.yaml`.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1
```

## Render Example

```powershell
helm template osmu .\infra\helm\osmu --namespace osmu
```

## Secret Handling

`secrets.create` defaults to `false`. Provide a Kubernetes Secret named
`osmu-secret`, or enable secret rendering only after replacing every placeholder
value.

Required secret keys:

- `MARIADB_USER`
- `MARIADB_PASSWORD`
- `MARIADB_ROOT_PASSWORD`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`
- `OSMU_ADMIN_PASSWORD`
- `OSMU_JWT_SECRET`
- `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY`

## Frontend Image Note

When deploying through the included ingress split, build the frontend image with:

```powershell
npm.cmd run build -- --mode production
```

The runtime expects API calls to go through `/api` on the same host.

## Production Gaps

Before real pilot use, add TLS, StorageClass selection, resource requests/limits,
backup/restore policy, secret rotation, cluster-specific NetworkPolicy review,
image build/scanning for the non-root backend/frontend images, monitoring, and HA topology decisions.

