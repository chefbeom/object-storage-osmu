# OSMU Dev Kubernetes Overlay

This overlay targets the `osmu-dev` namespace on the `192.168.35.60` development Kubernetes cluster.

## What It Changes

- Namespace: `osmu-dev`
- Ingress host: `osmu-dev.192.168.35.60.nip.io`
- Dev URL with current NodePort ingress: `http://osmu-dev.192.168.35.60.nip.io:30080`
- Ingress class: `nginx`
- TLS redirect: disabled for first dev deployment
- Storage class: `osmu-dev-local`
- MariaDB PV path: `/var/lib/osmu-dev/mariadb`
- MinIO PV path: `/var/lib/osmu-dev/minio`
- PV node affinity: `slave01`
- Backend/frontend node selector: `slave01`
- Backend artifact path: `/var/lib/osmu-dev/backend/app.jar`
- Backend MinIO client path: `/var/lib/osmu-dev/backend/bin/mc`
- Frontend artifact path: `/var/lib/osmu-dev/frontend/dist`
- Backend image: `eclipse-temurin:17-jre-jammy`
- Frontend image: `nginx:1.27-alpine`
- Backend `mc` config: `/tmp/.mc`

## Artifact Mode

This overlay avoids a private registry for the first dev deployment. Upload the backend jar, MinIO `mc` binary and frontend `dist` files to `slave01` before applying the overlay.

```bash
sudo mkdir -p /var/lib/osmu-dev/backend/bin /var/lib/osmu-dev/frontend/dist
sudo chown -R test:test /var/lib/osmu-dev/backend /var/lib/osmu-dev/frontend
```

## Deploy

Use the deploy helper from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-osmu-dev-k8s.ps1
```

The script creates `osmu-secret` with generated values if it does not already exist, then applies this overlay.

Backend and frontend images default to `osmu-backend:local` and `osmu-frontend:local`. Those images must exist on the cluster node or be replaced with registry images.
