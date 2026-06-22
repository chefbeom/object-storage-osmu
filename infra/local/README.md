# OSMU Local Infra

로컬 MariaDB와 MinIO 실행용 Docker Compose 구성이다.

## 실행

가장 쉬운 데모 실행:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local-demo.ps1
```

이 스크립트는 `infra/local/.env`가 없으면 `.env.example`에서 자동 생성하고, Docker Compose config 검증, `up -d --build`, Backend/DB/Storage/Frontend health 대기를 수행한 뒤 접속 URL과 기본 계정을 출력한다.

샘플 조직, 사용자, 버킷, 오브젝트, lifecycle rule, S3 access key까지 같이 생성하려면:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local-demo.ps1 -SeedDemo
```

seed 결과는 `.osmu-run/latest-demo.json`에 저장된다.

seed 후 포털/API/S3 access key smoke까지 확인하려면:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local-demo.ps1 -SeedDemo -VerifyDemo
```

수동 실행:

```powershell
Copy-Item .\infra\local\.env.example .\infra\local\.env
docker compose --env-file .\infra\local\.env -f .\infra\local\docker-compose.yml up -d
```

## 접속

- MariaDB: `localhost:3306`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Backend API: `http://localhost:8080/api`
- Frontend: `http://localhost:5173`

## 기본 계정

- MariaDB user: `osmu`
- MariaDB database: `osmu`
- MinIO root user: `minioadmin`
- MinIO root password: `minioadmin`

## Operations Report Mount

- The backend container mounts project `.osmu-run` at `/app/.osmu-run` read-only.
- Dashboard readiness can surface local operations reports such as `.osmu-run/latest-operations-readiness-convergence.json`, `.osmu-run/latest-kubernetes-operations-report-sync.json`, `.osmu-run/latest-data-flow-storage-plan.json`, and `.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json` without rebuilding the backend image.
- Override `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`, `OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH`, `OSMU_OPERATIONS_READINESS_DATA_FLOW_STORAGE_PLAN_REPORT_PATH`, or `OSMU_OPERATIONS_READINESS_DATA_FLOW_STORAGE_TRANSITION_RUNBOOK_REPORT_PATH` in `infra/local/.env` when a fixture or collected report lives under a subdirectory such as `.osmu-run/docker-local-demo/latest-operations-readiness-convergence.json`.

## MinIO CORS

`minio-cors.json`은 browser multipart upload가 part PUT 응답의 `ETag`를 읽을 수 있게 `ExposeHeaders`에 `ETag`를 포함한다.

`create-minio-buckets`는 기본 bucket 생성 후 이 CORS 설정을 적용하고, Backend도 bucket 생성 시 `OSMU_STORAGE_CORS_ENABLED=true`이면 같은 정책을 적용한다.

## Multipart Cleanup

Backend는 `OSMU_UPLOAD_CLEANUP_ENABLED=true`일 때 만료된 ACTIVE multipart upload session을 주기적으로 찾아 MinIO incomplete multipart upload를 abort한다.

기본 주기는 `OSMU_UPLOAD_CLEANUP_FIXED_DELAY_MS=300000`, batch size는 `OSMU_UPLOAD_CLEANUP_BATCH_SIZE=100`이다.

Frontend multipart upload는 `VITE_MULTIPART_UPLOAD_CONCURRENCY=4`를 기본값으로 part PUT을 병렬 전송한다. client는 이 값을 1~8 범위로 제한한다.

Part PUT 일시 실패 retry 기본값은 `VITE_MULTIPART_UPLOAD_PART_RETRIES=2`, backoff base delay는 `VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS=500`이다.

## 중지

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-local-demo.ps1
```

수동 중지:

```powershell
docker compose --env-file .\infra\local\.env -f .\infra\local\docker-compose.yml down
```

## 데이터 초기화

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-local-demo.ps1 -ResetData
```

수동 초기화:

```powershell
docker compose --env-file .\infra\local\.env -f .\infra\local\docker-compose.yml down -v
```

## 전체 재빌드

```powershell
docker compose --env-file .\infra\local\.env -f .\infra\local\docker-compose.yml up -d --build
```

## 통합 Smoke Test

Docker Desktop이 실행 중일 때 다음 명령으로 MariaDB, MinIO, Backend, Frontend 통합 흐름을 검증한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker-integration.ps1
```

검증 내용:

- Docker Compose config 검증
- Compose `up -d --build`
- Backend `/api/health`, `/api/storage/health`, `/api/database/health`
- Admin login
- Bucket 생성
- Object upload/list
- Multipart upload와 CORS `ETag` expose
- Frontend HTTP 200 확인
- Smoke bucket/object 정리
- 기본값은 검증 후 `docker compose down`을 수행한다.

컨테이너를 계속 띄워두려면:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker-integration.ps1 -KeepRunning
```

SigV4 smoke note:

- `verify-docker-integration.ps1` also verifies S3-style root `HEAD`, root `GET`, object `PUT/GET`, presigned-query object `GET`, mismatched payload hash `BadDigest`, and virtual-hosted-style object `PUT/GET` with AWS SigV4 and without `X-OSMU-Secret-Key`.

Virtual-hosted-style note:

- Backend accepts `Host: {bucket}.localhost` for `/api/s3` requests when `OSMU_S3_VIRTUAL_HOSTED_STYLE_ENABLED=true` and `OSMU_S3_VIRTUAL_HOSTED_STYLE_DOMAIN_SUFFIXES=localhost`.
- Production domains should configure DNS/proxy hosts like `{bucket}.storage.example.com` and set `OSMU_S3_VIRTUAL_HOSTED_STYLE_DOMAIN_SUFFIXES=storage.example.com`.

Real client smoke note:

- With the stack running, `scripts/verify-s3-client-smoke.ps1` verifies built-in SigV4 probes and can also verify AWS CLI (`aws`) or MinIO Client (`mc`) against `http://localhost:8080/api/s3`.
- Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-client-smoke.ps1 -Client auto
```

- Use `-RequireClient` to fail when neither client is installed.
- Use `-SkipManualSigV4` to skip built-in root HEAD/object/payload-hash/virtual-hosted probes.
- Use `-SkipVirtualHostedSmoke` when local DNS/proxy setup cannot route `{bucket}.localhost` style hosts.

## Seeded Demo Verification

이미 실행 중인 seeded demo를 확인하려면:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-local-demo.ps1
```

이 검증은 frontend bundle, backend health, admin/demo user login, 샘플 버킷/오브젝트, readonly 권한 경계, bucket tags, lifecycle rule, access key inventory, seeded S3 access key smoke를 확인한다.
