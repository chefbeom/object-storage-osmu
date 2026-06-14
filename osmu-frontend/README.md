# OSMU Frontend

Vue/Vite portal for the OSMU object storage prototype.

## Features

- Login/logout with JWT session refresh.
- Dashboard metrics and system status.
- Bucket create/list/delete/sync.
- Object upload, search, prefix browse, download, soft delete, restore, purge.
- Multipart upload with retry/resume state.
- Object tags and bucket tags.
- Bucket permissions and access keys.
- Lifecycle/retention controls, conflict checks, dry runs, S3 XML import/export.
- Admin users, organizations, usage, audit logs.

## Environment

Copy `.env.example` if local overrides are needed.

```powershell
Copy-Item .\.env.example .\.env -ErrorAction SilentlyContinue
```

Main values:

- `VITE_API_BASE_URL=http://localhost:8080/api`
- `VITE_MULTIPART_UPLOAD_CONCURRENCY=4`
- `VITE_MULTIPART_UPLOAD_PART_RETRIES=2`
- `VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS=500`
- `VITE_MULTIPART_UPLOAD_RETRY_JITTER_RATIO=0.25`

## Development

```powershell
npm install
npm run dev
```

Default dev URL: http://localhost:5173

From repository root, you can start both the in-memory backend and frontend dev server:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local-prototype.ps1 -JavaHome "C:\path\to\jdk17"
```

## Verify

```powershell
npm run test:unit
npm run build
```

`test:unit` currently covers shared tag parsing/formatting/validation rules used by object tags and bucket tags.

## Docker

The root Docker Compose stack builds this frontend image and serves it through nginx on port `5173`.

```powershell
docker compose --env-file ..\infra\local\.env -f ..\infra\local\docker-compose.yml up -d --build frontend
```

For normal local use, prefer the root command from `..\README.md` so MariaDB, MinIO, backend, and frontend start together.
