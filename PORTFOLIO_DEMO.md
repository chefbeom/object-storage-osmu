# OSMU Portfolio Demo

## One click

1. Start Docker Desktop.
2. Double-click `run-demo.cmd`.
3. Open `http://localhost:5173`.
4. Sign in with `admin` / `password`.

The first start builds four Docker Compose services, waits for health checks, and seeds a demo bucket, objects, roles, and access keys. Busy ports automatically move to free local ports.

## Commands

```powershell
.\run-demo.cmd
.\run-demo.cmd Status
.\run-demo.cmd Stop
.\run-demo.cmd Reset
```

`Reset` removes local MariaDB and MinIO volumes. It cannot be undone.

## Demo Flow

1. Dashboard: check storage, database, and operations readiness.
2. Quick Start: create a bucket and issue an S3 access key.
3. Storage and Objects: browse seeded data and upload an object.
4. Developer: select AWS CLI, JavaScript, Python, or Java client setup.
5. Admin: review access, policy, storage layout, billing, and identity workspaces.
6. Dev-Docs: inspect user, operator, and AI execution guides.

## Services

| Service | URL |
| --- | --- |
| OSMU Console | `http://localhost:5173` |
| Backend API | `http://localhost:8080/api` |
| MinIO Console | launcher output (default `http://localhost:9001`) |

Local credentials are for portfolio demonstration only. Do not reuse them in deployed environments.
