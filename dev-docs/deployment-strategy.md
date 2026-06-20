# OSMU Deployment Strategy

## Current HA/DR Deployment Controls

- Kubernetes base manifests include `ha.yaml` with PodDisruptionBudgets for backend, frontend, MariaDB, and legacy MinIO.
- Backend and frontend run `replicas: 2` in the base manifests and Helm defaults.
- Backend and frontend include hostname-based `topologySpreadConstraints` with `ScheduleAnyway` so development single-node clusters still work.
- Helm exposes these controls through `ha.podDisruptionBudgets` and `ha.topologySpread`.
- These controls reduce voluntary disruption risk, but they do not complete HA/DR by themselves. Production still needs MariaDB HA or managed DB, MinIO Operator Tenant pool validation, offsite backup/snapshot policy, restore drill evidence, and multi-node or multi-zone scheduling verification.
- After applying manifests or a Helm release, run `scripts/verify-kubernetes-ha-dr-readiness.ps1 -Namespace <namespace>` to collect live Deployment, StatefulSet, PDB, backup PVC, backup CronJob, and restore Job server-side dry-run evidence.
- For restore drills, use `scripts/run-kubernetes-dr-drill.ps1` to review the ordered sequence or run the confirmed flow. The wrapper calls optional `scripts/bootstrap-kubernetes-dr-bucket.ps1`, `scripts/prepare-kubernetes-restore-namespace.ps1`, optional `scripts/verify-kubernetes-dr-bucket-immutability.ps1`, `scripts/verify-kubernetes-backup-artifacts.ps1`, and `scripts/run-kubernetes-restore-drill.ps1` in order.
- If the restore namespace does not already contain the selected timestamp, use `scripts/transfer-kubernetes-backup-artifacts.ps1` or `scripts/run-kubernetes-dr-drill.ps1 -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts` with an external S3-compatible DR bucket and `osmu-dr-transfer-secret`.
- After the restored API is reachable, use `scripts/verify-kubernetes-restore-smoke.ps1` to collect post-restore API and optional S3 smoke evidence.
- After a live confirmed restore, use `scripts/write-kubernetes-dr-evidence-request.ps1` to generate `.osmu-run/latest-kubernetes-dr-evidence-request.json` and optionally submit it to the admin restore drill evidence API.
- For the full operator path, use `scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore` to run the wrapper, restore smoke, and evidence request sequence together and write `.osmu-run/latest-kubernetes-dr-finalize.json`.

이 문서는 OSMU 배포 전략을 정의한다.

## 1. 배포 목표

- 로컬 개발은 Docker Compose로 단순하게 실행한다.
- 운영 환경은 Kubernetes + Helm을 목표로 한다.
- 기업 환경에 설치 가능한 B2B 제품 구조를 만든다.

## 2. 배포 단계

### 2.1 Local

목적:

- 개발
- PoC
- 기능 테스트

구성:

- MariaDB
- MinIO
- Backend
- Frontend

도구:

- Docker Compose

### 2.2 Single Server

목적:

- 데모
- 소규모 테스트

구성:

- Docker Compose
- 외부 volume
- TLS optional

### 2.3 Kubernetes

목적:

- 운영
- 확장
- 고가용성

구성:

- Backend Deployment
- Frontend Deployment
- MariaDB StatefulSet 또는 외부 DB
- MinIO Tenant 또는 외부 MinIO
- Ingress
- Prometheus
- Grafana
- AlertManager

ServiceAccount/RBAC:

- Kubernetes ServiceAccount와 cluster RBAC 권한 경계는 `kubernetes-rbac-matrix.md`를 기준으로 한다.
- 기본 draft workload는 전용 ServiceAccount를 사용하지만 token automount를 끈다.
- Storage Expansion in-cluster kubectl runner는 `osmu-storage-expansion-runner` 전용 ServiceAccount/Role/RoleBinding을 사용한다. 권한은 `Tenant/osmu-minio` patch/update와 legacy `StatefulSet/osmu-minio` rollback에 필요한 namespace-scoped 동작으로 제한하고 Secret read, Pod exec, create/delete, cluster-scoped RBAC는 허용하지 않는다.
- 실제 cluster 적용 후 `scripts/verify-storage-expansion-rbac-auth.ps1 -Namespace <namespace>`로 `kubectl auth can-i` evidence를 남긴다.
- MinIO Operator CRD와 대상 Tenant가 준비된 cluster에서는 `scripts/verify-storage-expansion-server-dry-run.ps1 -Namespace <namespace> -ImpersonateRunner`로 server-side dry-run evidence를 남긴다.
- 애플리케이션 Pod에는 Kubernetes Role/RoleBinding을 부여하지 않는다.

### 2.4 Helm

목적:

- 설치 자동화
- 고객사별 설정 분리
- 업그레이드 관리

## 3. Docker Compose 파일

예정:

```text
infra/local/docker-compose.yml
infra/local/.env.example
```

## 4. Kubernetes 파일

예정:

```text
infra/k8s/
infra/helm/osmu/
```

현재 prototype에는 `infra/k8s/` manifest 초안과 `infra/helm/osmu/` chart 초안이 포함되어 있다.

포함 파일:

- `namespace.yaml`
- `serviceaccount.yaml`
- `storage-expansion-rbac.yaml`
- `configmap.yaml`
- `secret.example.yaml`
- `mariadb.yaml`
- `minio.yaml`
- `ha.yaml`
- `backend.yaml`
- `frontend.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `README.md`

검증:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-helm-chart.ps1
```

`secret.example.yaml`은 예시이며 `kustomization.yaml`에는 포함하지 않는다. Helm chart도 `secrets.create=false`를 기본값으로 유지한다. Kubernetes/Helm 초안에는 backend, frontend, MariaDB, MinIO의 기본 resource requests/limits와 backend egress, MariaDB/MinIO ingress NetworkPolicy draft, backend/frontend non-root security context, TLS ingress draft, Prometheus scrape annotation draft가 포함되어 있다. frontend nginx는 root 권한이 필요 없는 8080 포트로 실행하고 Service는 80 포트를 유지한다. Ingress는 `osmu-tls` TLS Secret을 참조하고 NGINX SSL redirect annotation을 켠다. Backend는 `/actuator/prometheus`를 노출하며 Prometheus annotation 또는 ServiceMonitor로 scrape한다. 운영 배포에서는 Secret manager, 인증서 발급/회전, StorageClass, replica/HA 정책을 별도로 확정해야 한다.

S3 호환 클라이언트용 공개 endpoint는 `OSMU_S3_PUBLIC_ENDPOINT`, region은 `OSMU_S3_REGION`으로 설정한다. Helm chart는 `config.s3PublicEndpoint`, `config.s3Region` 값을 ConfigMap에 반영하고, 기본 Kubernetes manifest는 `https://osmu.local/api/s3`, `us-east-1`을 사용한다. 개발 overlay는 `http://osmu-dev.192.168.35.60.nip.io:30080/api/s3`로 공개 endpoint를 덮어쓴다.

현재 prototype에는 `infra/k8s/` 초안이 포함되어 있다.

포함 파일:

- `namespace.yaml`
- `configmap.yaml`
- `secret.example.yaml`
- `mariadb.yaml`
- `minio.yaml`
- `backend.yaml`
- `frontend.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `README.md`

검증:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1
```

`secret.example.yaml`은 예시이며 `kustomization.yaml`에는 포함하지 않는다. 운영 배포에서는 Secret manager, TLS, StorageClass, resource limit, replica/HA 정책을 별도로 확정해야 한다.

현재 prototype에는 `infra/k8s/` 초안이 포함되어 있다.

포함 파일:

- `namespace.yaml`
- `configmap.yaml`
- `secret.example.yaml`
- `mariadb.yaml`
- `minio.yaml`
- `backend.yaml`
- `frontend.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `README.md`

검증:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1
```

`secret.example.yaml`은 예시이며 `kustomization.yaml`에는 포함하지 않는다. 운영 배포에서는 Secret manager, TLS, StorageClass, resource limit, replica/HA 정책을 별도로 확정해야 한다.

### 4.1 MinIO 용량 증설 전략

운영형 OSMU의 MinIO 용량 증설은 `dev-docs/minio-pool-expansion.md`를 기준으로 한다.

- 현재 `infra/k8s/minio.yaml`의 단일 StatefulSet은 MVP 배포용이며, 운영형 증설 기준이 아니다.
- 운영형 증설은 MinIO Operator Tenant의 `pools`에 새 server pool을 추가하는 방식으로 진행한다.
- 제품 기본 topology는 pool당 `4 servers x 4 volumesPerServer`를 권장한다.
- 증설 요청은 요청 용량을 만족하는 `servers`, `volumesPerServer`, PVC 크기, StorageClass를 계산한 뒤 새 pool로 반영한다.
- 적용 전에는 backup/restore readiness gate를 확인하고, 적용 후에는 `mc admin info`, OSMU health, real S3 client smoke를 실행한다.

## 5. 설정 전략

설정 분리:

- local
- dev
- staging
- production

Spring profile:

- `local`
- `dev`
- `prod`

## 6. Secret 관리

Local:

- `.env`

Kubernetes:

- Kubernetes Secret
- External Secrets optional

금지:

- secret Git commit
- credential log 출력

Rotation:

- Follow `secret-rotation-policy.md` before pilot handoff.
- Follow `backup-restore-drill.md` before durable pilot handoff.
- Generate `.osmu-run/latest-operations-handoff-package.json` with `scripts/write-operations-handoff-package.ps1` before production/B2B handoff so runbook, troubleshooting, rollback, support escalation, known gaps, and target evidence references are reviewed without storing secret values.
- Rotate admin password, MariaDB password, MinIO root password, user access keys, and TLS certificate through the environment secret manager.
- `OSMU_JWT_SECRET` rotation invalidates active sessions and must use a maintenance window.
- `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY` rotation requires access key re-issue or a re-encryption migration.
- Record rotation events without recording secret values.

## 7. 운영 배포 기준

운영 전 필수:

- TLS
- 인증 활성화
- 관리자 초기 비밀번호 변경
- MariaDB 백업 설정
- MinIO 백업/복제 정책
- 로그 확인
- 모니터링 확인

## 8. 제품화 목표

- 설치 스크립트
- Helm Chart
- 설치 가이드
- 업그레이드 가이드
- rollback 가이드
- 라이선스 설정

