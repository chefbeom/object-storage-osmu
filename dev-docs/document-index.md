# OSMU Document Index

This index points to the useful project documents for the current prototype. The root `README.md` is the fastest starting point for running and verifying the project.

## Start Here

1. `../README.md` - prototype overview, run commands, verification commands.
2. `PRODUCT_REQUIREMENTS.md` - product goal, MVP scope, final target scope.
3. `PROJECT_MEMORY.md` - long-term project memory and direction.
4. `prototype-status.md` - current implemented scope, latest verification, blockers, and next work.
5. `mvp-release-checklist.md` - MVP v0.1 release gate checklist and go/no-go rules.
6. `development-roadmap.md` - roadmap from MVP to product.

## Engineering Design

- `system-architecture.md` - high-level architecture.
- `api-spec.md` - REST and S3-compatible API notes.
- `openapi-mvp.json` - machine-readable MVP REST/S3 API contract snapshot.
- `database-design.md` - MariaDB schema and metadata design.
- `backend-design.md` - Spring Boot backend design.
- `frontend-design.md` - Vue portal design.
- `local-dev-env.md` - local Docker/MariaDB/MinIO environment.

## Operations

- `security-design.md` - auth, access keys, permissions, security policy.
- `backup-recovery.md` - backup and recovery direction.
- `operation-monitoring.md` - health checks, backup readiness status, logs, metrics, monitoring.
- `deployment-strategy.md` - Docker Compose, Kubernetes, Helm direction.
- `minio-pool-expansion.md` - MinIO Pod/PV pool-based capacity expansion strategy.
- `../infra/k8s/README.md` - Kubernetes draft manifest guide.
- `../infra/k8s/README.md` - Kubernetes draft manifest guide.

## Testing

- `test-strategy.md` - test strategy and quality gates.
- `test-cases.md` - detailed test cases.
- `../scripts/verify-local.ps1` - local static/unit/build/backend verification.
- `../scripts/verify-prototype-prerequisites.ps1` - check Java, Node/npm, Docker, real S3 clients, and runtime endpoints before deeper prototype verification.
- `../scripts/verify-prototype-release.ps1` - one-command MVP release gate that combines prerequisites, build verification, backend tests, runtime smoke, seeded demo smoke, and S3 smoke.
- `../scripts/write-mvp-audit.ps1` - write a human-readable MVP audit from the latest release evidence report.
- `../scripts/write-mvp-release-decision.ps1` - write lightweight demo and durable pilot go/no-go decisions from the latest release evidence report.
- `../scripts/write-mvp-release-notes.ps1` - write lightweight demo release notes from the latest release evidence, audit, and decision reports.
- `../scripts/verify-mvp-release-decision.ps1` - self-test release decision logic against synthetic lightweight and durable reports.
- `../scripts/verify-openapi-contract.ps1` - parse and verify the machine-readable MVP OpenAPI contract and frontend API function coverage.
- `../scripts/verify-k8s-manifests.ps1` - verify the Kubernetes draft manifest set and secret handling.
- `../scripts/verify-mvp-release-artifacts.ps1` - check latest release JSON, audit report, and decision report are synchronized.
- `../scripts/start-local-prototype.ps1` - start Docker-free in-memory backend and frontend; fails fast when target ports are already occupied.
- `../scripts/verify-prototype-gate.ps1` - run the complete lightweight prototype gate in one command.
- `../scripts/verify-lightweight-prototype.ps1` - smoke test a running Docker-free prototype.
- `../scripts/seed-lightweight-demo.ps1` - seed a running Docker-free prototype with demo org, users, buckets, objects, lifecycle rules, and access key.
- `../scripts/verify-lightweight-demo.ps1` - verify seeded portal data, frontend bundle, scoped permissions, tags, lifecycle, access key inventory, and S3 SigV4 access with the seeded key.
- `../scripts/stop-local-prototype.ps1` - stop Docker-free prototype processes; use `-ForcePorts` to clean up stale child listeners on default ports.
- `../scripts/verify-docker-integration.ps1` - full Docker integration smoke.
- `../scripts/verify-s3-client-smoke.ps1` - S3 client compatibility smoke, including built-in SigV4 probes for object tagging, range GET, conditional requests, CopyObject, bucket tagging, and multi-delete.

## Worklogs

- `worklog/main/worklog-main.md` - main branch historical worklog.
- `worklog/codex/frontend-backend-mvp/worklog-codex-frontend-backend-mvp.md` - current Codex branch worklog.

## Current Stack

- Backend: Spring Boot
- Frontend: Vue + Vite
- Metadata DB: MariaDB
- Object storage: MinIO
- Local infra: Docker Compose
- Kubernetes draft: `infra/k8s`
- Kubernetes draft: `infra/k8s`
- API surface: REST API + S3-compatible API

## Current Prototype Gate

- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1 -SkipDocker -JavaHome <jdk17>`
- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1`
- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker-integration.ps1` after Docker Desktop is running
