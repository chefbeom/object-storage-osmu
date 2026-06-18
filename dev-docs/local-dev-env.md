# OSMU Local Development Environment

이 문서는 OSMU 로컬 개발 환경 설계를 정의한다.

## 1. 목표

개발자가 같은 환경에서 OSMU를 실행할 수 있게 한다.

로컬 환경은 다음을 제공한다.

- MariaDB
- MinIO
- MinIO Console
- Backend
- Frontend

## 2. 포트

| 서비스 | 포트 | 설명 |
| --- | --- | --- |
| Backend | 8080 | Spring Boot API |
| Frontend | 5173 | Vite Dev Server |
| MariaDB | 3306 | Metadata DB |
| MinIO API | 9000 | S3 API |
| MinIO Console | 9001 | MinIO Web Console |

## 3. Docker Compose 구성

구성 파일:

```text
infra/local/docker-compose.yml
infra/local/.env.example
infra/local/README.md
osmu-backend/.env.example
osmu-backend/src/main/resources/application-local.yaml
osmu-frontend/.env.example
```

서비스:

- `mariadb`
- `minio`

현재 포함:

- `mariadb`
- `minio`
- `create-minio-buckets`
- `backend`
- `frontend`

추후 선택:

- `prometheus`
- `grafana`

## 4. 환경변수

### MariaDB

```text
MARIADB_DATABASE=osmu
MARIADB_USER=osmu
MARIADB_PASSWORD=osmu-password
MARIADB_ROOT_PASSWORD=root-password
```

### MinIO

```text
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
```

### Backend

```text
SPRING_DATASOURCE_URL=jdbc:mariadb://localhost:3306/osmu
SPRING_DATASOURCE_USERNAME=osmu
SPRING_DATASOURCE_PASSWORD=osmu-password
OSMU_FLYWAY_ENABLED=true
OSMU_STORAGE_ENDPOINT=http://localhost:9000
OSMU_STORAGE_ACCESS_KEY=minioadmin
OSMU_STORAGE_SECRET_KEY=minioadmin
OSMU_STORAGE_MODE=minio
OSMU_METADATA_MODE=mariadb
OSMU_STORAGE_CORS_ENABLED=true
OSMU_STORAGE_CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
OSMU_UPLOAD_CLEANUP_ENABLED=true
OSMU_UPLOAD_CLEANUP_INITIAL_DELAY_MS=60000
OSMU_UPLOAD_CLEANUP_FIXED_DELAY_MS=300000
OSMU_UPLOAD_CLEANUP_BATCH_SIZE=100
OSMU_OBJECT_RETENTION_ENABLED=true
OSMU_OBJECT_RETENTION_DAYS=30
OSMU_OBJECT_RETENTION_INITIAL_DELAY_MS=120000
OSMU_OBJECT_RETENTION_FIXED_DELAY_MS=3600000
OSMU_OBJECT_RETENTION_BATCH_SIZE=100
OSMU_ACCESS_KEY_PROVISIONING_MODE=minio
OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY=local-dev-access-key-secret-encryption-key-change-me
OSMU_ACCESS_KEY_MC_PATH=mc
OSMU_ACCESS_KEY_MINIO_ALIAS=osmu-minio
OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=false
OSMU_STORAGE_EXPANSION_APPLY_RUNNER_ENABLED=false
OSMU_STORAGE_EXPANSION_ROLLBACK_RUNNER_ENABLED=false
OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_ENABLED=false
OSMU_STORAGE_EXPANSION_GITOPS_REPOSITORY_PATH=
OSMU_STORAGE_EXPANSION_GIT_PATH=git
OSMU_STORAGE_EXPANSION_GH_PATH=gh
OSMU_STORAGE_EXPANSION_GITOPS_BASE_BRANCH=main
OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_TIMEOUT_SECONDS=60
OSMU_STORAGE_EXPANSION_POST_RUN_VERIFIER_ENABLED=true
OSMU_STORAGE_EXPANSION_POST_RUN_BUCKET_PREFIX=osmu-expansion-smoke
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_MASKING_ENABLED=true
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_MAX_OUTPUT_CHARS=16384
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_ENABLED=true
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_DAYS=90
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_BATCH_SIZE=100
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_INITIAL_DELAY_MS=180000
OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_FIXED_DELAY_MS=3600000
OSMU_DATA_FLOW_RETENTION_ENABLED=true
OSMU_DATA_FLOW_RETENTION_DAYS=90
OSMU_DATA_FLOW_RETENTION_BATCH_SIZE=1000
OSMU_DATA_FLOW_RETENTION_INITIAL_DELAY_MS=300000
OSMU_DATA_FLOW_RETENTION_FIXED_DELAY_MS=21600000
OSMU_STORAGE_EXPANSION_KUBECTL_PATH=kubectl
OSMU_STORAGE_EXPANSION_HELM_PATH=helm
OSMU_STORAGE_EXPANSION_HELM_CHART_PATH=./infra/helm/osmu
OSMU_STORAGE_EXPANSION_NAMESPACE=osmu
OSMU_STORAGE_EXPANSION_RUNNER_TIMEOUT_SECONDS=30
OSMU_STORAGE_EXPANSION_RUNNER_PREFLIGHT_TIMEOUT_SECONDS=3
OSMU_S3_SIGV4_CLOCK_SKEW_SECONDS=900
OSMU_S3_VIRTUAL_HOSTED_STYLE_ENABLED=true
OSMU_S3_VIRTUAL_HOSTED_STYLE_DOMAIN_SUFFIXES=localhost
OSMU_ADMIN_LOGIN_ID=admin
OSMU_ADMIN_PASSWORD=password
OSMU_ADMIN_EMAIL=admin@example.com
OSMU_ADMIN_NAME=Admin
OSMU_JWT_SECRET=local-dev-jwt-secret-change-me-32-chars
OSMU_JWT_ACCESS_TOKEN_TTL_SECONDS=3600
OSMU_JWT_REFRESH_TOKEN_TTL_SECONDS=604800
VITE_MULTIPART_UPLOAD_CONCURRENCY=4
VITE_MULTIPART_UPLOAD_PART_RETRIES=2
VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS=500
VITE_MULTIPART_UPLOAD_RETRY_JITTER_RATIO=0.25
```

Backend actuator는 `/actuator/health`, `/actuator/info`, `/actuator/metrics`, `/actuator/prometheus`를 노출한다. multipart cleanup metric은 `/actuator/metrics/osmu.multipart.cleanup.sessions`, retention purge metric은 `/actuator/metrics/osmu.object.retention.purge.objects`, version retention purge metric은 `/actuator/metrics/osmu.object.version.retention.purge.versions`, data-flow retention metric은 `/actuator/metrics/osmu.data.flow.retention.events`와 `/actuator/metrics/osmu.data.flow.retention.runs`에서 확인한다.

## 5. 실행 순서

### 5.1 사전 점검

Frontend/static 검증은 Node.js/npm이 필요하고, Backend Gradle test는 JDK 17+가 필요하다.

```powershell
.\scripts\verify-prototype-prerequisites.ps1 -RequireNode
```

`verify-local.ps1`, `verify-prototype-prerequisites.ps1`는 `-JavaHome`, `JAVA_HOME`, `PATH`, 흔한 Windows JDK 설치 경로를 순서대로 확인한다. Java가 없으면 Backend test gate는 실패하므로 JDK 17+ 설치 후 아래처럼 명시한다.

```powershell
.\scripts\verify-local.ps1 -JavaHome C:\jdk-17
```

JDK 없이 Frontend/static gate만 확인하려면 다음처럼 실행한다.

```powershell
.\scripts\verify-local.ps1 -SkipDocker -SkipBackend
```

Current-machine MVP demo auto start:

```powershell
.\scripts\start-mvp-demo.ps1 -Verify -ForcePorts
.\scripts\stop-mvp-demo.ps1 -ForcePorts
```

`start-mvp-demo.ps1` selects Docker full stack when Docker daemon is available, Spring Boot in-memory prototype when JDK 17+ is available, and frontend mock demo as the fallback.

Docker 없이 in-memory backend/frontend만 빠르게 띄우는 prototype mode도 JDK 17+가 필요하다. Java가 없으면 port를 열기 전에 실패하므로 다음처럼 명시한다.

```powershell
.\scripts\start-local-prototype.ps1 -JavaHome C:\jdk-17
```

빠른 실행:

```powershell
.\scripts\start-local-demo.ps1
```

이 명령은 `infra/local/.env`가 없으면 `.env.example`에서 생성하고, Docker Compose config 검증, `up -d --build`, Backend/Database/Storage/Frontend health 대기, 접속 URL 출력을 수행한다.

샘플 데이터 포함 실행:

```powershell
.\scripts\start-local-demo.ps1 -SeedDemo
```

`-SeedDemo`는 샘플 조직, org admin, 일반 사용자, 스트리밍/AI 버킷, 태그, lifecycle rule, 샘플 오브젝트, S3 access key를 생성하고 `.osmu-run/latest-demo.json`에 접속 정보를 저장한다.

샘플 데이터 포함 실행 후 검증:

```powershell
.\scripts\start-local-demo.ps1 -SeedDemo -VerifyDemo
```

이미 실행 중인 seeded demo 검증:

```powershell
.\scripts\verify-local-demo.ps1
```

Docker 관련 스크립트는 `.osmu-run\docker-config`를 `DOCKER_CONFIG`로 사용한다. 따라서 Windows 사용자 홈의 `.docker\config.json` 권한 문제와 Docker daemon 미실행 문제를 분리해서 진단할 수 있다. `Docker daemon is not available`이면 Docker Desktop을 켠 뒤 같은 명령을 다시 실행한다.

중지:

```powershell
.\scripts\stop-local-demo.ps1
```

데이터까지 초기화:

```powershell
.\scripts\stop-local-demo.ps1 -ResetData
```

수동 실행:

1. Docker 실행
2. `Copy-Item .\infra\local\.env.example .\infra\local\.env`
3. `docker compose --env-file .\infra\local\.env -f .\infra\local\docker-compose.yml up -d`
4. MariaDB 연결 확인
5. MinIO Console 접속
6. Backend 상태 확인
7. Frontend 접속

## 6. 검증 명령

```text
GET http://localhost:8080/api/health
GET http://localhost:8080/api/database/health
GET http://localhost:8080/api/storage/health
```

자동 검증:

```powershell
.\scripts\verify-local.ps1
```

환경 일부가 없을 때:

```powershell
.\scripts\verify-local.ps1 -SkipDocker -SkipBackend
.\scripts\verify-local.ps1 -SkipFrontend
```

Docker 통합 smoke test:

```powershell
.\scripts\verify-docker-integration.ps1
```

이 명령은 Docker Compose `up -d --build`, Backend health, storage/database health, admin login, bucket 생성, object upload/list, multipart upload, MinIO CORS `ETag` expose, multipart parts list, refresh URL 재발급, S3 SigV4 root HEAD/list, bucket tagging PUT/GET/DELETE, checksum object PUT/HEAD/GET, bucket sync 후 checksum 보존, S3 multipart checksum complete와 AWS-style multipart ETag, `x-amz-sdk-checksum-algorithm` 기반 UploadPart 자동 checksum/ListParts/stored-checksum complete, S3 multi-delete Quiet/Content-MD5/per-key Error, payload hash mismatch `BadDigest`, checksum mismatch `BadDigest`, virtual-hosted-style PUT/GET, frontend HTTP 200을 확인하고 기본값으로 `docker compose down`을 수행한다. 컨테이너를 유지하려면 `-KeepRunning`을 사용한다.

Durable MVP demo gate:

```powershell
.\scripts\verify-durable-demo-preflight.ps1
.\scripts\verify-durable-demo-gate.ps1
```

The preflight command does not start containers. It checks Node/npm, Docker CLI, Docker daemon, Docker Compose config, and the selected real S3 client path, then writes `.osmu-run/latest-durable-demo-preflight.json` and `.osmu-run/latest-durable-demo-preflight.md`.

The gate command is the strongest single local demo verification command. It prepares `infra/local/.env` when missing, runs the durable preflight unless `-SkipPreflight` is set, checks Node/Docker/real S3 client prerequisites, starts the full Docker local demo, runs Browser E2E, runs Docker integration smoke, runs real S3 client smoke through the selected client (`docker-mc` by default), writes `.osmu-run/latest-durable-demo-gate.json` and `.osmu-run/latest-durable-demo-gate.md`, and stops the stack unless `-KeepRunning` is set.

Durable MVP finalize wrapper:

```powershell
.\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc
.\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc -PlanOnly
```

The finalize wrapper is the release-candidate local sequence for a Docker-ready machine. It runs durable preflight, backend Gradle tests, the durable demo gate, durable release artifact generation, and `verify-mvp-demo-readiness.ps1 -FailIfDurablePending`. `-PlanOnly` writes `.osmu-run/latest-durable-mvp-finalize.json` and `.osmu-run/latest-durable-mvp-finalize.md` with the planned commands without starting containers.

Docker local demo Browser E2E:

```powershell
.\scripts\verify-browser-e2e-local-demo.ps1
```

This command starts the full Docker stack, seeds demo data, runs the seeded REST/S3 demo smoke, runs Playwright Browser E2E against the Docker frontend, and stops the stack by default. Use `-KeepRunning` when you want to inspect the demo after verification.

The Docker local demo backend mounts project `.osmu-run` into `/app/.osmu-run` read-only. This lets the Spring Boot readiness API expose generated operations reports, including `.osmu-run/latest-operations-readiness-convergence.json`, from the full MariaDB/MinIO demo. `verify-browser-e2e-local-demo.ps1` writes a Docker-local convergence fixture under `.osmu-run/docker-local-demo/`, sets `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH` for the backend container, and enables the Playwright convergence dashboard check.

Real S3 client smoke test:

```powershell
.\scripts\verify-s3-client-smoke.ps1 -Client auto
.\scripts\verify-s3-client-smoke.ps1 -Client all -RequireClient
.\scripts\verify-s3-client-smoke.ps1 -Client docker-mc -RequireClient
.\scripts\verify-s3-client-smoke.ps1 -Client auto -SkipVirtualHostedSmoke
```

The script always runs built-in SigV4 probes for root HEAD, root bucket list, bucket tagging PUT/GET/DELETE, checksum object PUT/HEAD/GET, checksum preservation after bucket sync, S3 multipart checksum complete plus AWS-style multipart ETag recomputation, `x-amz-sdk-checksum-algorithm` UploadPart auto checksum/ListParts/stored-checksum complete, S3 multi-delete Quiet/Content-MD5/per-key Error, payload hash mismatch, checksum mismatch, and virtual-hosted-style routing unless `-SkipManualSigV4` or `-SkipVirtualHostedSmoke` is set. If `aws` is on PATH, this also verifies real AWS CLI calls for `GET /api/s3`, object upload/head/list/download/delete, and `s3api put-object --checksum-algorithm SHA256` with HEAD/GET checksum exposure. If host `mc` is on PATH, this verifies MinIO Client upload/stat/list/cat/delete. If Docker daemon is available, `-Client auto`, `-Client all`, or `-Client docker-mc` can run MinIO Client from the `minio/mc` container image and connect back to localhost through `host.docker.internal`. If no client exists and `-RequireClient` is not set, the script warns and skips external client checks.

MinIO Console:

```text
http://localhost:9001
```

## 7. 개발 데이터

초기 seed:

- admin user
- default organization
- sample bucket optional

## 8. 로컬 환경 원칙

- Secret은 `.env.example`에는 샘플만 둔다.
- 실제 `.env`는 Git에 커밋하지 않는다.
- 컨테이너 volume을 사용해 데이터 유지 가능하게 한다.
- reset 방법을 문서화한다.

## 9. 첫 구현 체크리스트

완료:

- `infra/local/docker-compose.yml`
- `infra/local/.env.example`
- MariaDB volume
- MinIO volume
- Backend profile `local`
- `application-local.yaml`
- Health API
- Backend Dockerfile
- Frontend Dockerfile
- Docker Compose backend/frontend service
- Docker 통합 smoke test script
- Local demo start/stop script
- MinIO bucket CORS JSON과 Backend CORS provisioner

남은 항목:

- Docker Desktop 실행 환경에서 `.\scripts\verify-docker-integration.ps1` 실제 실행
- 실제 MinIO Access Key provisioning E2E 확인
- Backend를 Docker 밖에서 `local` profile로 실행하면서 `OSMU_STORAGE_CORS_ENABLED=true`를 사용할 경우 `mc` binary가 PATH에 있어야 한다. 없으면 `OSMU_STORAGE_CORS_ENABLED=false`로 끄고 수동 CORS 설정을 사용한다.

