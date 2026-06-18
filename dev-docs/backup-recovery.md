# OSMU Backup and Recovery

MVP drill runbook: `backup-restore-drill.md`.

## Current Kubernetes DR Baseline

- `infra/k8s/backup.yaml` and the Helm backup template schedule MariaDB dumps and MinIO mirrors into a backup PVC.
- `infra/k8s/examples/restore-from-backup.example.yaml` is a destructive restore example that must be copied and edited for an isolated restore target.
- `infra/k8s/ha.yaml` and the Helm `ha` template add PodDisruptionBudgets so voluntary node maintenance does not silently evict the only MariaDB or legacy MinIO Pod.
- Backend/frontend default to two replicas with topology spread, improving portal/API availability during voluntary disruptions.
- `scripts/verify-kubernetes-ha-dr-readiness.ps1 -Namespace <namespace>` records live Deployment/StatefulSet/PDB/PVC/CronJob status plus restore Job server-side dry-run evidence.
- `scripts/run-kubernetes-backup-drill.ps1 -Namespace <namespace>` creates one-off backup Jobs from the MariaDB/MinIO backup CronJobs and records Job/Pod/log evidence.
- `scripts/prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -ServerDryRunOnly` validates a disposable restore-target namespace manifest set before creating resources.
- `scripts/prepare-kubernetes-restore-namespace.ps1 -RestoreNamespace osmu-restore-drill -Apply -Wait` creates the restore-target core stack and checks that the backup PVC, services, ServiceAccount, and secret inventory are present.
- `scripts/verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -ServerDryRunOnly` validates the read-only artifact preflight Job against the API server.
- `scripts/verify-kubernetes-backup-artifacts.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -CleanupJob` checks `metadata.sql`, optional `metadata.sql.sha256`, and MinIO mirror object count/bytes before restore.
- `scripts/run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -ServerDryRunOnly` validates the isolated restore Job against the API server without creating it.
- `scripts/run-kubernetes-restore-drill.ps1 -RestoreNamespace osmu-restore-drill -BackupTimestamp <timestamp> -ConfirmRestore` creates the restore Job only after an explicit confirmation flag and refuses source-namespace restore unless explicitly overridden.
- `scripts/run-kubernetes-dr-drill.ps1 -BackupTimestamp <timestamp> -ServerDryRunOnly` runs the ordered non-destructive DR drill validation sequence.
- `scripts/run-kubernetes-dr-drill.ps1 -BackupTimestamp <timestamp> -ConfirmRestore` runs the ordered restore sequence after explicit operator confirmation. It does not copy backup artifacts between namespaces.
- `scripts/bootstrap-kubernetes-dr-bucket.ps1 -DrEgressCidr <cidr>` creates or reuses the external S3-compatible DR bucket through `osmu-dr-transfer-secret`, enables bucket versioning, sets default object-lock retention, verifies the result, and writes `.osmu-run/latest-kubernetes-dr-bucket-bootstrap.json`.
- `scripts/verify-kubernetes-dr-bucket-immutability.ps1 -DrEgressCidr <cidr>` checks the external S3-compatible DR bucket through `osmu-dr-transfer-secret` and writes `.osmu-run/latest-kubernetes-dr-bucket-immutability.json`. Live success requires bucket reachability, versioning enabled, and default object-lock retention mode matching `GOVERNANCE_OR_COMPLIANCE` or `COMPLIANCE`.
- `scripts/transfer-kubernetes-backup-artifacts.ps1 -BackupTimestamp <timestamp> -DrEgressCidr <cidr>` exports the selected timestamp from the source `osmu-backup-data` PVC to an external S3-compatible DR bucket and imports it into the restore namespace PVC. It requires `osmu-dr-transfer-secret` in each active namespace and writes `.osmu-run/latest-kubernetes-backup-artifact-transfer.json`. Export mounts source backup data read-only; import mounts restore backup data read-write; both transfer Jobs use a read-only root filesystem and `MC_CONFIG_DIR=/tmp/.mc` on an `emptyDir` mount. The helper also sets bounded CPU/memory requests/limits, `activeDeadlineSeconds`, and `ttlSecondsAfterFinished`.
- `scripts/run-kubernetes-dr-drill.ps1 -BackupTimestamp <timestamp> -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -DrEgressCidr <cidr> -ConfirmRestore` includes the external DR bucket bootstrap, immutability preflight, and export/import step before artifact preflight.
- `scripts/verify-kubernetes-restore-smoke.ps1 -ApiBase <restore-api> -RunS3ClientSmoke` records post-restore API health, admin login, optional restored bucket/object download, and real S3 client smoke evidence into `.osmu-run/latest-kubernetes-restore-smoke.json`.
- `scripts/write-kubernetes-dr-evidence-request.ps1 -MetadataRowCount <count>` converts the Kubernetes DR wrapper evidence, backup artifact preflight logs, optional DR bucket bootstrap/immutability evidence, and restore smoke evidence into `.osmu-run/latest-kubernetes-dr-evidence-request.json` for `POST /api/admin/backup/restore-drill-evidence`. External artifact transfer success requires passed DR bucket immutability evidence, and wrapper-driven bootstrap success requires passed bootstrap evidence. Add `-Submit` only when the target admin API is reachable and an admin operator intentionally records the evidence.
- `scripts/finalize-kubernetes-dr-drill.ps1 -BackupTimestamp <timestamp> -BootstrapDrBucket -VerifyDrBucketImmutability -TransferArtifacts -ConfirmRestore -RunS3ClientSmoke -MetadataRowCount <count>` runs the DR wrapper, post-restore smoke, and evidence request generation in one operator sequence and writes `.osmu-run/latest-kubernetes-dr-finalize.json` plus `.osmu-run/latest-kubernetes-dr-finalize.md`. Use `-SubmitEvidence` only when the admin API evidence should be recorded.
- `.github/workflows/kubernetes-dr-finalizer-ci.yml` exposes the same finalizer as a manual GitHub Actions workflow. Default runs are plan-only, live runs require `OSMU_KUBECONFIG_BASE64`, and confirmed restore/evidence submit paths require `confirm_restore=true`.
- This is still a pilot DR baseline only. Production DR needs offsite backup or snapshots, restore drill evidence, MinIO replication or pool recovery testing, MariaDB HA/managed DB, and RPO/RTO proof.

이 문서는 OSMU 백업과 복구 전략을 정의한다.

## 1. 백업 대상

OSMU는 두 종류의 데이터를 가진다.

### 1.1 Metadata

저장 위치:

- MariaDB

대상:

- 사용자
- 조직
- 버킷 메타데이터
- 권한
- Access Key 메타데이터
- 쿼터
- 감사 로그
- 시스템 설정

### 1.2 Object Data

저장 위치:

- MinIO

대상:

- 영상
- 이미지
- 문서
- 로그 파일
- AI 학습 데이터
- 백업 파일

## 2. MVP 백업 전략

MVP에서는 자동 백업보다 복구 가능한 구조와 문서를 먼저 제공한다.

포함:

- MariaDB dump 가이드
- MinIO bucket replication 가이드
- MinIO object export 가이드
- 장애 시 복구 절차 문서

## 3. MariaDB 백업

기본 방식:

```text
mariadb-dump
```

백업 주기:

- 개발: 수동
- 운영: 매일 1회 이상

보관 정책:

- 일간 7일
- 주간 4주
- 월간 6개월

## 4. MinIO 백업

후보:

- MinIO replication
- `mc mirror`
- 외부 S3 호환 저장소 복제
- 원격 MinIO 클러스터 복제
- NAS 백업

MVP:

- `mc mirror` 기반 수동 백업 가이드

제품화:

- 버킷 단위 백업 정책
- 스케줄 백업
- 백업 상태 대시보드
- 실패 알림

## 5. 복구 시나리오

### 5.1 MariaDB 장애

1. 서비스 중지
2. MariaDB 복구
3. dump restore
4. Backend 실행
5. Health API 확인

### 5.2 MinIO 데이터 손실

1. 장애 버킷 확인
2. 백업 대상 확인
3. object restore
4. bucket metadata와 실제 object 정합성 확인

### 5.3 전체 서버 장애

1. 새 서버 준비
2. Docker Compose 또는 Kubernetes 배포
3. MariaDB 복구
4. MinIO 데이터 복구
5. Backend/Frontend 실행
6. API 검증

## 6. 복구 목표

초기 목표:

- RPO: 24시간
- RTO: 수동 복구 기준 4시간 이내

제품화 목표:

- RPO: 1시간 이내
- RTO: 1시간 이내

## 7. 향후 기능

- 백업 정책 UI
- 버킷별 백업 설정
- 외부 S3 백업
- 백업 상태 조회 API
- 백업 실패 알림
- 특정 시점 복구

