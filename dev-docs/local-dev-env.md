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

Backend actuator는 `/actuator/health`, `/actuator/info`, `/actuator/metrics`, `/actuator/prometheus`를 노출한다. multipart cleanup metric은 `/actuator/metrics/osmu.multipart.cleanup.sessions`, retention purge metric은 `/actuator/metrics/osmu.object.retention.purge.objects`, version retention purge metric은 `/actuator/metrics/osmu.object.version.retention.purge.versions`에서 확인한다.

## 5. 실행 순서

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

이 명령은 Docker Compose `up -d --build`, Backend health, storage/database health, admin login, bucket 생성, object upload/list, multipart upload, MinIO CORS `ETag` expose, multipart parts list, refresh URL 재발급, S3 SigV4 root HEAD/list, bucket tagging PUT/GET/DELETE, checksum object PUT/HEAD/GET, bucket sync 후 checksum 보존, S3 multipart checksum complete, S3 multi-delete Quiet/Content-MD5/per-key Error, payload hash mismatch `BadDigest`, checksum mismatch `BadDigest`, virtual-hosted-style PUT/GET, frontend HTTP 200을 확인하고 기본값으로 `docker compose down`을 수행한다. 컨테이너를 유지하려면 `-KeepRunning`을 사용한다.

Real S3 client smoke test:

```powershell
.\scripts\verify-s3-client-smoke.ps1 -Client auto
.\scripts\verify-s3-client-smoke.ps1 -Client all -RequireClient
.\scripts\verify-s3-client-smoke.ps1 -Client auto -SkipVirtualHostedSmoke
```

The script always runs built-in SigV4 probes for root HEAD, root bucket list, bucket tagging PUT/GET/DELETE, checksum object PUT/HEAD/GET, checksum preservation after bucket sync, S3 multipart checksum complete, S3 multi-delete Quiet/Content-MD5/per-key Error, payload hash mismatch, checksum mismatch, and virtual-hosted-style routing unless `-SkipManualSigV4` or `-SkipVirtualHostedSmoke` is set. If `aws` or `mc` is on PATH, this also verifies real S3 client calls for `GET /api/s3`, object upload, head/stat, list, download/cat, delete, and cleanup through `http://localhost:8080/api/s3`. If no client exists and `-RequireClient` is not set, the script warns and skips external client checks.

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
- MinIO bucket CORS JSON과 Backend CORS provisioner

남은 항목:

- Docker Desktop 실행 환경에서 `.\scripts\verify-docker-integration.ps1` 실제 실행
- 실제 MinIO Access Key provisioning E2E 확인
- Backend를 Docker 밖에서 `local` profile로 실행하면서 `OSMU_STORAGE_CORS_ENABLED=true`를 사용할 경우 `mc` binary가 PATH에 있어야 한다. 없으면 `OSMU_STORAGE_CORS_ENABLED=false`로 끄고 수동 CORS 설정을 사용한다.

