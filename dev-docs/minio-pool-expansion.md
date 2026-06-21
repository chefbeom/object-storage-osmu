# MinIO Pool Expansion Design

이 문서는 OSMU의 MinIO 저장소 확장 방향을 정의한다. 결론부터 말하면, OSMU의 제품형 용량 증설은 **Pod와 PV를 임의로 하나씩 붙이는 방식이 아니라 MinIO server pool을 추가하는 방식**을 기본 전략으로 한다.

## 1. 핵심 결정

OSMU의 운영형 MinIO 확장은 **server pool 단위 증설**을 기준으로 한다.

선택한 방향:

- 기본 저장소는 MinIO distributed/erasure coding 구성을 목표로 한다.
- 증설 요청은 "요청 용량만큼 Pod를 단순히 늘림"이 아니라 "요청 용량을 만족하는 pool topology를 계산해 새 pool을 추가함"으로 처리한다.
- Kubernetes에서는 MinIO Operator Tenant의 `pools` 항목에 `pool-0`, `pool-1`처럼 새 server pool을 추가하는 모델을 기준으로 한다.
- 기존 Pod에 PV만 하나씩 추가하거나 StatefulSet `replicas`만 늘리는 방식은 운영형 확장 전략으로 사용하지 않는다.
- 같은 pool 안에서는 Pod 수, PVC 수, PVC 크기, StorageClass를 일관되게 유지한다.
- 적용 전에는 실제 사용할 MinIO Operator 또는 AIStor CRD 버전의 `servers`, `volumesPerServer`, volume count 제약을 반드시 검증한다.

## 2. 용어 정리

- Server: MinIO server Pod 1개를 의미한다.
- Volume: MinIO Pod에 붙는 PVC/PV 1개를 의미한다.
- Server pool: 같은 형태의 server와 volume 묶음이다.
- `servers`: pool 안의 MinIO Pod 수이다.
- `volumesPerServer`: Pod 1개당 붙는 PVC/PV 수이다.
- Raw capacity: `servers * volumesPerServer * pvcSize`로 계산하는 물리적 원시 용량이다.
- Usable capacity: erasure coding parity, metadata, 운영 여유분을 제외하고 실제 고객에게 제공 가능한 용량이다.

예시:

```text
servers = 4
volumesPerServer = 4
pvcSize = 2Ti

raw capacity = 4 * 4 * 2Ti = 32Ti
usable capacity = raw capacity - erasure coding/parity/운영 여유분
```

OSMU 화면과 API에서는 고객에게 raw capacity와 usable capacity를 구분해서 보여줘야 한다.

## 3. 권장 기본 구조

### 3.1 MVP 또는 데모용 최소 구조

사용자가 말한 기본 구조인 `4 pods x 1 PV`는 개념 검증 또는 작은 dev/staging 환경에서는 이해하기 쉽다.

```text
Pool 0
- minio-pool-0-0 + pv-0
- minio-pool-0-1 + pv-1
- minio-pool-0-2 + pv-2
- minio-pool-0-3 + pv-3
```

다만 이 구조는 제품 기본값으로는 약하다. 현재 MinIO 계열 Operator/AIStor CRD 문서에서는 pool의 전체 volume 수에 대한 최소 조건이 존재할 수 있으므로, `4 pods x 1 PV = 4 volumes` 구성은 target CRD에 따라 적용이 거부되거나 운영 여유가 부족할 수 있다.

따라서 이 구조는 **MVP 설명용 또는 제한된 데모용**으로만 둔다.

### 3.2 제품 기본 권장 구조

운영형 제품 기본값은 다음을 권장한다.

```text
Pool 0
- minio-pool-0-0 + pv-0-a, pv-0-b, pv-0-c, pv-0-d
- minio-pool-0-1 + pv-1-a, pv-1-b, pv-1-c, pv-1-d
- minio-pool-0-2 + pv-2-a, pv-2-b, pv-2-c, pv-2-d
- minio-pool-0-3 + pv-3-a, pv-3-b, pv-3-c, pv-3-d
```

기본값:

- `servers: 4`
- `volumesPerServer: 4`
- 전체 volume 수: `16`
- PVC 크기: 고객사 용량 계획에 따라 `1Ti`, `2Ti`, `4Ti` 등으로 산정

이 구성이 더 적합한 이유:

- erasure coding 구성이 더 안정적이다.
- volume 수가 충분해 운영형 CRD 제약을 만족하기 쉽다.
- Pod 장애와 disk 장애를 나누어 생각하기 좋다.
- pool 단위 용량 계산과 증설 이력을 제품 기능으로 만들기 쉽다.

현재 개발 클러스터에 `slave01`부터 `slave04`까지 worker node가 있다면, 운영형 dev/staging 검증에서는 4개 Pod를 서로 다른 worker node에 분산하는 구성을 목표로 한다.

## 4. 용량 증설 요청 처리 방식

관리자가 "스토리지 용량 증설"을 요청하면 OSMU는 다음 흐름으로 처리한다.

1. 현재 pool별 사용량, raw capacity, 예상 usable capacity를 조회한다.
2. 요청 용량과 예상 증가 추세를 확인한다.
3. 새 pool의 `servers`, `volumesPerServer`, `pvcSize`, `storageClassName`을 계산한다.
4. 계산 결과를 관리자에게 계획서로 보여준다.
5. 확장 전 backup/restore readiness gate를 확인한다.
6. MinIO Operator Tenant manifest 또는 Helm values에 새 pool을 추가한다.
7. rollout과 MinIO health를 검증한다.
8. `mc admin info`, OSMU health, S3 client smoke를 실행한다.
9. 증설 이력을 OSMU DB와 worklog에 기록한다.

중요한 판단:

- 증설은 "요청된 용량만큼 Pod 수를 무작정 늘림"이 아니다.
- 작은 요청도 운영형이면 pool shape를 유지한다.
- 큰 요청은 PVC 크기를 키운 새 pool을 추가하거나, 동일 shape의 pool을 여러 개 추가한다.
- 기존 pool 안의 일부 PVC만 크게 키우는 방식은 기본 전략이 아니다.

## 5. 증설 구조 예시

기본 pool이 부족하면 같은 형태의 새 pool을 추가한다.

```text
Pool 0
- 4 servers
- 4 volumes per server
- 1Ti per volume
- raw capacity 16Ti

Pool 1
- 4 servers
- 4 volumes per server
- 1Ti per volume
- raw capacity 16Ti
```

용량이 더 필요한 고객사는 PVC 크기를 키운 pool을 추가할 수 있다.

```text
Pool 2
- 4 servers
- 4 volumes per server
- 4Ti per volume
- raw capacity 64Ti
```

단, 같은 pool 안의 volume 크기는 동일하게 유지한다.

## 6. 피해야 할 방식

다음 방식은 기본 전략으로 사용하지 않는다.

- 기존 MinIO Pod 하나에 PV만 추가하는 방식
- 특정 PV 하나만 크게 확장하는 방식
- StatefulSet replica 수만 증가시키는 방식
- 서로 다른 크기의 PV를 같은 pool에 섞는 방식
- hostPath 기반 PV를 운영 저장소로 사용하는 방식

이 방식들은 erasure coding 균형, 장애 복구, 운영 자동화, 용량 예측을 어렵게 만든다.

## 7. 예외적으로 허용할 수 있는 방식

기존 PVC 용량 확장은 다음 조건에서만 단기 대응으로 허용한다.

- StorageClass가 volume expansion을 지원한다.
- 같은 pool의 모든 PVC를 같은 크기로 확장한다.
- 확장 전 백업/복구 가능성을 확인한다.
- 확장 후 MinIO health, OSMU bucket sync, S3 client smoke를 실행한다.

이 방식은 긴급 용량 확보에는 유용하지만, OSMU의 기본 확장 전략은 아니다.

## 8. OSMU 제품 기능으로 발전할 방향

OSMU는 장기적으로 Storage Expansion Manager를 제공한다.

목표 기능:

- MinIO pool별 raw capacity 조회
- MinIO pool별 예상 usable capacity 조회
- pool별 server 수, volume 수, PVC 크기, StorageClass 조회
- 사용량 70%, 80%, 90% threshold 알림
- 새 pool 추가 계획 생성
- 필요한 Pod/PV 수량과 예상 용량 계산
- MinIO Operator Tenant values 또는 manifest 생성
- Helm upgrade 또는 Kubernetes API 기반 적용
- 확장 전 backup/restore readiness gate 확인
- 확장 후 `mc admin info`, health check, S3 smoke 자동 실행
- 관리자 화면에서 확장 요청 상태와 이력 확인

관리자 화면에 필요한 상태:

- `REQUESTED`
- `PLANNED`
- `APPROVED`
- `APPLYING`
- `VERIFYING`
- `COMPLETED`
- `FAILED`
- `CANCELED`

## 9. 운영 확장 절차 초안

1. 현재 사용량과 증가 추세를 확인한다.
2. MariaDB metadata backup과 MinIO object backup/replication 상태를 확인한다.
3. 새 worker node 또는 disk를 준비한다.
4. 새 PV 또는 StorageClass 용량을 준비한다.
5. MinIO Operator Tenant에 새 pool을 추가한다.
6. rollout 상태와 MinIO health를 확인한다.
7. OSMU backend `/api/storage/health`를 확인한다.
8. bucket create/delete smoke와 real S3 client smoke를 실행한다.
9. OSMU 문서와 worklog에 확장 결과를 기록한다.

## 10. 현재 MVP와의 차이

현재 `infra/k8s/minio.yaml`은 MVP 배포용 단일 MinIO StatefulSet이다.

```text
replicas: 1
args: server /data
volumeClaimTemplates: minio-data 1개
```

따라서 현재 매니페스트에서 바로 replica만 늘리는 것은 운영형 확장이 아니다. 운영형 확장은 MinIO Operator Tenant 또는 별도 distributed MinIO topology로 전환한 뒤 pool 단위로 진행한다.

## 11. 다음 구현 작업

- MinIO Operator 기반 Tenant manifest 초안 작성
- Helm chart의 `minio.tenant.enabled=true` 조건부 MinIO Operator Tenant 렌더링과 `minio.pools` values 구조 검증
- Storage Expansion Manager 요구사항 작성
- Storage Expansion Request API 초안 작성
- 관리자 화면의 증설 요청/계획/검증 이력 UI 초안 작성
- `osmu-dev`에서 `4 servers x 4 volumesPerServer` distributed MinIO 검증 환경 준비
- 기존 단일 MinIO에서 운영형 MinIO로 이전하는 migration runbook 작성

## 11.1 Storage Profile linkage

Storage Expansion grows MinIO capacity by server pool. Storage Profile chooses the intended bucket behavior on top of those pools.

MVP profile mapping:

| Profile | Pool selector | Parity direction | Notes |
| --- | --- | --- | --- |
| `PERFORMANCE` | `osmu.storage-profile=performance` | Lowest allowed parity or dedicated low-parity pool | RAID0-like speed-first behavior. Requires explicit user reason and admin approval. |
| `STANDARD` | `osmu.storage-profile=standard` | Default erasure coding parity | Default bucket behavior when no assignment row exists. |
| `DURABLE` | `osmu.storage-profile=durable` | Higher parity or dedicated durable pool | Durability-first behavior for source media, backups, and archive data. |

Current implementation stores the profile assignment and exposes MinIO hints. It does not yet rewrite existing objects, set a live MinIO bucket placement policy, or change cluster parity automatically. That work belongs to a future Storage Profile runner:

1. Verify target MinIO Operator/AIStor CRD supports the selected pool/parity policy.
2. Validate that the target pool exists and has enough free usable capacity.
3. Apply bucket placement/ILM or storage-class policy if supported.
4. Optionally rewrite existing objects into the target profile pool.
5. Run `mc admin info`, OSMU health, bucket sync, and S3 smoke.
6. Record request/apply evidence in OSMU and worklog.

## 12. 참고한 공식 문서

- [MinIO Kubernetes expansion guide](https://docs.min.io/enterprise/aistor-object-store/operations/scaling/expansion/expand-aistor-kubernetes/)
- [MinIO Operator/AIStor CRD reference](https://docs.min.io/enterprise/aistor-object-store/reference/kubernetes/aistor-crd-v1/)
- [MinIO erasure coding concepts](https://docs.min.io/aistor/operations/core-concepts/erasure-coding/)

### Storage Expansion 구현 상태

- Storage Expansion server dry-run runner 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/dry-run-runner`로 `kubectl diff` 또는 `helm diff`를 서버에서 실행하고 `exitCode/timedOut/output`을 실행 이력으로 저장한다. 기본 비활성 설정에서는 실제 명령을 실행하지 않고 `SKIPPED`를 기록한다.
- Storage Expansion server apply runner 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/apply-runner`로 `kubectl apply --server-side` 또는 `helm upgrade`를 서버에서 실행하고 `APPLY` 실행 이력을 저장한다. 기본 비활성 설정에서는 `SKIPPED`만 기록하며, 활성 상태에서 성공하면 request를 `APPLIED`로 자동 전환한다.
- Storage Expansion server rollback runner 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/rollback-runner`로 `helm rollback` 또는 `kubectl rollout undo`를 서버에서 실행하고 `ROLLBACK` 실행 이력을 저장한다. 기본 비활성 설정에서는 `SKIPPED`만 기록한다.
- Storage Expansion runner preflight 구현 완료: `GET /api/admin/storage-expansion/runner-preflight`로 dry-run/apply/rollback/GitOps PR runner enablement와 `kubectl`, `helm`, `helm diff`, `git`, `gh`, `gh auth status`, GitOps repository `.git` metadata, `git -C {repositoryPath} status --short` readiness를 확인한다. 기본 disabled 상태에서는 실제 CLI probe를 실행하지 않고 `DISABLED`를 반환한다. 각 check는 설정/권한/도구 문제를 고치기 위한 `remediation` 힌트를 포함하고 UI에 표시된다.
- Storage Expansion runner Kubernetes RBAC 초안 구현 완료: raw manifest와 Helm chart에 `osmu-storage-expansion-runner` ServiceAccount/Role/RoleBinding을 추가했다. 권한은 `Tenant/osmu-minio` patch/update와 legacy `StatefulSet/osmu-minio` rollback에 필요한 namespace-scoped `get/patch/update` 중심 동작으로 제한하며 Secret read, Pod exec, create/delete, cluster-scoped RBAC는 verifier로 차단한다. Helm upgrade/rollback과 GitOps PR runner는 기본적으로 외부 GitOps/CI identity를 사용한다.
- Storage Expansion runner live authorization evidence 스크립트 구현 완료: `scripts/verify-storage-expansion-rbac-auth.ps1`는 `kubectl auth can-i --as=system:serviceaccount:<namespace>:osmu-storage-expansion-runner`로 허용/거부 권한을 검증하고 `.osmu-run/latest-storage-expansion-rbac-auth.json` evidence를 남긴다. `-PlanOnly`는 cluster 없이 실행 계획만 출력한다.
- Storage Expansion server-side dry-run evidence 스크립트 구현 완료: `scripts/verify-storage-expansion-server-dry-run.ps1`는 MinIO Operator Tenant CRD 존재, 기존 `Tenant/osmu-minio` 존재, `kubectl apply --server-side --dry-run=server` 결과를 `.osmu-run/latest-storage-expansion-server-dry-run.json`에 남긴다. `-ImpersonateRunner`로 runner ServiceAccount 기준 dry-run을 확인할 수 있고, `-PlanOnly`는 cluster 없이 실행 계획만 출력한다.
- Storage Expansion finalization wrapper 구현 완료: `scripts/finalize-storage-expansion.ps1`는 RBAC auth evidence, server-side dry-run evidence, optional backend dry-run runner, optional backend apply runner, optional storage backend telemetry evidence writer 호출을 하나의 `.osmu-run/latest-storage-expansion-finalize.json`/`.md` 보고서로 묶는다. 실제 apply는 `-RunBackendApply -ConfirmApply`가 함께 있고 같은 실행에서 RBAC/server-side dry-run evidence를 스킵하지 않을 때만 진행되며 admin password와 bearer token은 evidence에 기록하지 않는다.
- Storage Expansion post-run verifier 구현 완료: apply/rollback runner가 `SUCCESS`를 반환하면 database health, object storage health, S3 put/get/list smoke를 자동 실행하고 실패 시 execution result를 `FAILED`로 기록한다. apply verifier 실패 시 request는 `APPLIED`로 자동 전환되지 않는다.
- Storage backend telemetry evidence writer 구현 완료: `scripts/write-storage-backend-telemetry-evidence.ps1`는 `mc admin info --json` file input 또는 명시적 `-Execute` 결과를 pool/server/drive summary, online/offline state, total/used/free bytes, input SHA-256으로 요약해 `.osmu-run/latest-storage-backend-telemetry.*`에 남긴다. raw admin output, credential, bearer token, MinIO root credential은 저장하지 않는다.
- Storage expansion finalizer는 `-RunStorageBackendTelemetryEvidence -StorageBackendTelemetryAdminInfoJsonPath <path>` 옵션으로 post-expansion `mc admin info --json` 파일을 같은 finalizer run에서 요약하고 `.osmu-run/latest-storage-backend-telemetry.*` evidence path를 report에 연결한다.
- Storage Expansion execution log sanitizer 구현 완료: runner/manual/GitOps execution의 `command`, `output`, `notes` 저장 전에 password/secret/token/access key/authorization/S3 signature/URL password를 masking하고 output retention limit을 적용한다.
- Storage Expansion execution output retention 구현 완료: scheduler와 수동 실행 API가 retention 기간이 지난 execution output만 redaction marker로 교체하고 record/evidence/audit trail은 유지한다.
- Storage Expansion execution output retention dashboard panel 구현 완료: ADMIN dashboard에서 pending/redacted/failed count를 확인하고 `Run retention`으로 수동 redaction job을 실행할 수 있다.
- Storage Expansion dashboard summary API/panel 구현 완료: `GET /api/admin/storage-expansion/summary`로 전체 request/execution aggregate와 recent executions를 조회하고, ADMIN dashboard palette의 `storage-expansion` widget/panel에서 open/applied/rejected request 수, open capacity, 실패/timeout 실행 수, 최근 요청/실행, execution count를 확인할 수 있다. MariaDB summary는 request/execution aggregate query, `status/result/timed_out` index, `ORDER BY id DESC LIMIT` query를 사용해 전체 request/execution row를 application memory로 가져오지 않는다.
- Storage Expansion Request API MVP 구현 완료: `GET/POST /api/admin/storage-expansion/requests`, `PATCH /api/admin/storage-expansion/requests/{requestId}/status`
- 관리자 화면 Storage Expansion panel MVP 구현 완료: capacity, server count, PV/server, reason 입력 및 상태 변경
- Storage Expansion manifest preview 구현 완료: `GET /api/admin/storage-expansion/requests/{requestId}/manifest`로 MinIO Operator Tenant patch와 Helm values patch 초안을 반환
- Helm chart `minio.pools` 구조 구현 완료: 기본값은 MVP 단일 StatefulSet을 유지하고, `minio.tenant.enabled=true`인 경우 MinIO Operator Tenant CRD와 `minio.pools` 기반 server pool topology를 렌더링한다. 실제 적용 전에는 target MinIO Operator CRD schema 검증이 필요하다.
- Storage Expansion manifest artifact download 구현 완료: `GET /api/admin/storage-expansion/requests/{requestId}/manifest/{tenant|helm|bundle}`로 GitOps/Helm 첨부용 YAML을 내려받음
- Storage Expansion dry-run execution plan 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/execution-plan`로 승인 요청의 preflight checklist, artifact SHA-256, 추천 kubectl/helm 명령을 생성
- Storage Expansion dry-run evidence 기록 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/dry-run-execution`로 `KUBECTL_DIFF` 또는 `HELM_DIFF` 결과를 현재 artifact SHA-256과 함께 실행 이력으로 저장
- Storage Expansion GitOps draft plan 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/gitops-plan`로 승인 요청의 브랜치명, `[Feat][I]` 커밋 메시지, PR 제목/본문, 변경 파일 경로, review checklist를 생성
- Storage Expansion GitOps artifact bundle 구현 완료: `GET /api/admin/storage-expansion/requests/{requestId}/gitops-artifacts/bundle`로 승인 요청의 tenant patch, Helm values, README를 ZIP으로 export
- Storage Expansion GitOps PR runner 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner`로 `git checkout -B` 이후 GitOps artifact를 repository 내부 경로에 쓰고 branch/commit/push/PR 생성을 fail-fast로 실행한다. 기본 비활성 상태에서는 `GITOPS_PR / SKIPPED` 실행 이력을 남긴다. enabled runner 단위테스트는 fake `git`/`gh`로 artifact write, command order, push, PR URL capture, repository escape 차단, branch protection 실패 분류와 실패 후 command 중단을 검증한다. execution response는 notes의 `failureReason`을 `failureReason` 필드로도 내려주며, ADMIN Storage Expansion 실행 이력 UI는 이 값을 badge로 분리 표시해 운영자가 실패 원인을 빠르게 확인할 수 있다.
- Storage Expansion GitOps PR evidence 기록 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution`로 외부 GitOps PR URL, merge SHA, pipeline URL을 검증해 `GITOPS_PR` 실행 이력으로 저장
- Storage Expansion execution history 구현 완료: `GET/POST /api/admin/storage-expansion/requests/{requestId}/executions`로 dry-run, GitOps PR, Helm diff, kubectl diff, apply, rollback 결과를 기록/조회
- Storage Expansion execution apply linkage 구현 완료: `POST /api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply`로 성공한 `APPLY` 또는 `GITOPS_PR` 실행 기록을 `APPLIED` evidence에 자동 연결
- `APPLIED` 상태는 `APPROVED` 요청에서만 가능하며 적용 증거(`appliedEvidence`)를 필수 기록한다.
- 후속: GitOps PR runner enabled 환경의 실제 remote 권한/branch protection 검증, storage expansion finalizer의 실제 Kubernetes cluster 실행, Helm diff, Kubernetes apply executor의 실행 결과와 자동 연결
