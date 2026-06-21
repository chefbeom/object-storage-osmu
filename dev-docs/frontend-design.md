## Admin Lifecycle Rule UI

- Admin dashboard has a lifecycle rule form for `OBJECT_VERSION` and `TRASH_OBJECT`.
- Operators can set rule name, enabled flag, priority, prefix, tag filter, retention days, and batch size.
- Rule list supports edit/delete and shows target, retention, batch, prefix, and tags.
- UI calls `GET/POST/DELETE /api/admin/object-lifecycle/rules`.
- Rule list has Dry run action to preview matched candidates, bytes, cutoff, and truncation state before purge.
- Conflict report shows overlapping enabled rules and refreshes after rule save/delete.
- S3 Lifecycle XML area exports current rules and imports compatible lifecycle XML into OSMU rules.
- Bucket detail area has a Bucket Lifecycle panel for selected bucket S3 XML load/save/delete.
- Bucket Lifecycle panel uses `getBucketLifecycleS3Xml`, `putBucketLifecycleS3Xml`, `deleteBucketLifecycleS3Xml`.
- Bucket detail area has a Bucket Tags panel for selected bucket S3 tagging load/save/delete.
- Bucket Tags panel accepts `key=value,key2=value2`, validates the same 50 bucket tag limit as Backend, converts input to a JSON tag map, and uses `GET/PUT/DELETE /api/buckets/{bucketName}/tags`.
- Tag parsing/formatting validation lives in `src/utils/tags.js` and is covered by `npm run test:unit`.
# OSMU Frontend Design

## Data Flow Export Note

- Data Flow Monitoring panel provides CSV export through `data-flow-export-button`.
- Data Flow Monitoring panel provides daily rollup CSV export through `data-flow-daily-rollup-export-button`.
- Data Flow Monitoring panel refreshes the materialized daily rollup store through `data-flow-daily-rollup-materialize-button` and `materializeDataFlowDailyRollup`.
- Data Flow Monitoring panel reads the materialized daily rollup store through `data-flow-daily-rollup-materialized-load-button` and `getMaterializedDataFlowDailyRollup`.
- Data Flow Monitoring panel exports the materialized daily rollup store through `data-flow-daily-rollup-materialized-export-button` and `downloadMaterializedDataFlowDailyRollupCsv`.
- Data Flow Monitoring panel reads long-term UTC-month aggregate analytics through `data-flow-monthly-rollup-load-button` and `getDataFlowMonthlyRollup`, with source selection from live events or materialized daily rollups.
- Data Flow Monitoring panel exports monthly aggregate analytics through `data-flow-monthly-rollup-export-button` and `downloadDataFlowMonthlyRollupCsv`.
- Data Flow Monitoring panel refreshes and reads the dedicated monthly aggregate store through `data-flow-monthly-rollup-materialize-button`, `data-flow-monthly-rollup-materialized-load-button`, `data-flow-monthly-rollup-materialized-export-button`, `materializeDataFlowMonthlyRollup`, `getMaterializedDataFlowMonthlyRollup`, and `downloadMaterializedDataFlowMonthlyRollupCsv`.
- Data Flow Monitoring panel renders retention status and manual cleanup controls through `data-flow-retention-panel`, `data-flow-retention-event-days`, `data-flow-retention-rollup-days`, `data-flow-retention-monthly-rollup-days`, `data-flow-retention-deleted`, `data-flow-retention-failed`, `data-flow-retention-refresh-button`, and `data-flow-retention-run-button`, backed by `getDataFlowRetentionStatus` and `runDataFlowRetention`.
- Data Flow Monitoring panel renders repository/storage readiness through `data-flow-storage-panel`, `data-flow-storage-status`, `data-flow-storage-rows`, and `data-flow-storage-window`, backed by `getDataFlowStorageStatus`. The panel shows the current aggregate-store boundary and does not imply partitioned/time-series storage is enabled.
- Export uses the same date, bucket, actor, source, operation, status, and limit filters as the on-screen monitoring panel.
- Data Flow Monitoring panel renders source/operation trend points through `data-flow-trend-chart` and daily bucket/source/operation rollup rows through `data-flow-daily-rollup`.
- Data Flow Monitoring separates upload, download, and internal copy traffic in the summary and bucket rows.
- Chargeback preview uses `getBillingPricingPolicy`, `saveBillingPricingPolicy`, `getBillingPricingPolicyProposals`, `createBillingPricingPolicyProposal`, `approveBillingPricingPolicyProposal`, `approveBillingPricingPolicyProposalPriceList`, `getChargebackPreview`, `getChargebackDailyRollup`, `getChargebackAlerts`, `getChargebackAlertNotificationPreview`, `queueChargebackAlertNotifications`, `getChargebackAlertNotificationOutbox`, `recordChargebackAlertNotificationAdapterResult`, `sendChargebackAlertNotificationAdapter`, `getChargebackAdapterRetryWorkerStatus`, `runChargebackAdapterRetryWorker`, `getChargebackPaymentProviderAdapterReadiness`, `createChargebackInvoiceDrafts`, `getChargebackInvoiceDrafts`, `approveChargebackInvoiceDraft`, `finalizeChargebackInvoiceDraft`, `getChargebackFinalInvoices`, `requestChargebackInvoicePayment`, `queueChargebackPaymentProviderHandoff`, `getChargebackPaymentProviderHandoffs`, `recordChargebackPaymentProviderHandoffAdapterResult`, `sendChargebackPaymentProviderHandoffAdapter`, `recordChargebackInvoicePayment`, `downloadChargebackPreviewCsv`, `downloadChargebackDailyRollupCsv`, and `downloadChargebackInvoiceDraftCsv` through `BillingChargebackPanel` in Admin; it exposes date/rate/event-limit inputs, warning/critical threshold policy inputs, notification channel/target preview inputs, payment provider/target handoff inputs, ADMIN-only policy save, pricing policy proposal/internal approval/commercial price-list reference controls (`billing-pricing-policy-proposal-approve-button`, `billing-pricing-policy-price-list-approve-button`), scoped data-flow daily rollup chargeback trend metrics/list/export (`chargeback-daily-rollup-metrics`, `chargeback-daily-rollup-list`, `chargeback-daily-rollup-export-button`), scoped alert list, scoped notification payload preview, scoped notification outbox/history with send/block/retry controls (`chargeback-notification-adapter-send-button`, `chargeback-notification-adapter-block-button`, `chargeback-notification-adapter-retry-button`), adapter retry worker dry-run/run controls (`chargeback-adapter-retry-worker-refresh-button`, `chargeback-adapter-retry-worker-run-button`), payment provider adapter readiness rows (`chargeback-payment-adapter-readiness-list`) showing generic/CARD/BANK/TAX/ERP webhook readiness and native API pending status, scoped CSV export, draft invoice CSV export, ADMIN-only draft invoice persistence/internal approval/finalization list, final invoice payment request/handoff/paid controls, payment provider handoff outbox/history with send/block/retry controls (`chargeback-payment-handoff-adapter-send-button`, `chargeback-payment-handoff-adapter-block-button`, `chargeback-payment-handoff-adapter-retry-button`), organization cost rows, and preview totals. Preview/queue/readiness/trend actions do not send external notifications or payments; `sendChargebackAlertNotificationAdapter`, `sendChargebackPaymentProviderHandoffAdapter`, and the retry worker attempt only configured generic notification webhook, `SLACK` channel Slack webhook, `EMAIL` channel SMTP relay, and payment webhook adapters. Payment provider codes beginning with `CARD`, `BANK`, `TAX`, or `ERP` can route to provider-specific webhook profiles, with optional HMAC signature headers on generic notification/payment webhooks.

## Multipart Refresh Note

- `refreshMultipartUpload(bucketName, payload)` API wrapper를 제공한다.
- multipart 실패 시 `sessionStorage`에 `uploadId`, file fingerprint, completed part ETag를 저장한다.
- retry 시 parts list API로 MinIO에 이미 올라간 part ETag를 조회하고, refresh API로 만료된 part URL을 재발급받는다.
- sessionStorage ETag와 server-side part ETag를 병합한 뒤 완료된 part는 skip하고 남은 part만 업로드한다.
- tab reload 후에도 pending multipart 목록을 sessionStorage에서 복구하고, 같은 bucket/key/tags/file fingerprint가 선택되면 Resume 버튼으로 이어 올린다.
- Backend가 반환한 session `expiresAt`으로 pending multipart 만료 여부를 표시하고, 만료 후 24시간이 지난 local resume session은 자동 정리한다.
- 사용자 취소는 abort API를 호출하고 resume session을 삭제한다.

이 문서는 Vue 기반 OSMU Web Portal 설계를 정의한다.

## 1. Frontend 역할

Web Portal은 관리자와 사용자가 OSMU를 브라우저에서 사용할 수 있게 하는 관리 도구다.

주요 기능:

- 로그인
- 대시보드
- 버킷 목록
- 파일 탐색기
- 파일 업로드/다운로드/삭제
- Access Key 관리
- 사용자 관리
- 조직 관리
- 감사 로그 조회
- 시스템 상태 확인

## 2. 기술 스택

- Vue 3
- Vite
- Vue Router
- Pinia
- Fetch API 또는 Axios
- Vue Router는 history mode를 사용한다. 운영/컨테이너 nginx는 `try_files $uri $uri/ /index.html` fallback으로 `/login`, `/dashboard` 같은 직접 접근 URL을 처리한다.

## 3. 화면 구조

```text
/login
/dashboard
/storage
/objects
/developer
/admin
/audit
```

## 4. 레이아웃

관리 도구이므로 실용적이고 조용한 UI를 우선한다.

구성:

- 좌측 사이드바
- 상단 상태바
- 메인 컨텐츠 영역
- 표 기반 목록
- 모달 기반 생성/삭제 확인

## 5. 주요 화면

### 5.1 LoginView

기능:

- `/login` 전용 진입 화면.
- loginId 입력.
- password 입력.
- 비밀번호 보이기/숨김 toggle.
- 자동 로그인 checkbox. 활성화하면 refresh/access token을 `localStorage`에 저장해 브라우저 재시작 후에도 session 복원을 시도한다.
- 아이디 저장 checkbox. 활성화하면 loginId만 `localStorage`에 저장한다.
- 관리자/개발자 로그인 mode 선택.
- 관리자 mode는 `/admin`으로 이동하며 용량 증설, RAID/JBOD 계획, IAM user/access key 발급, 권한 부여 같은 운영 기능으로 이어진다.
- 관리자 계정은 Developer navigation도 볼 수 있어 Access Key/API Key를 통한 S3 호환 저장 작업을 직접 수행할 수 있다.
- 개발자 mode는 `/developer`로 이동하며 Access Key/API Key를 이용한 S3 호환 저장 흐름을 강조한다.
- 로그인 실패 메시지 표시.
- 인증이 필요한 `/dashboard`, `/storage`, `/objects`, `/admin`, `/audit` 접근 시 session이 없으면 `/login?redirect=...`로 이동한다.
- 저장된 session 복구가 만료/폐기된 token 때문에 실패하면 `/login?redirect=...&reason=session-expired`로 이동하고, login 화면에 재로그인 안내를 표시한다.
- 저장된 session 복구가 서버 오류 등 예상 외 이유로 실패하면 `/login?redirect=...&reason=session-invalid`로 이동하고, 저장된 로그인 정보를 확인할 수 없다는 안내를 표시한다.
- `/admin`은 `ADMIN`, `ORG_ADMIN`만 접근 가능하며 `/audit`은 `ADMIN`, `AUDITOR`만 접근 가능하다.
- `USER` role은 관리자 mode를 선택해도 실제 role 기준으로 `/developer` 개발자 작업 화면으로 이동한다.
- Sidebar navigation은 role 기준으로 표시한다. 개발자 사용자는 Dashboard, Storage, Objects, Developer만 보고 Admin/Audit는 보지 않는다. `AUDITOR`는 Dashboard와 Audit만 보고, dashboard palette에서는 read-only 감사/상태 widget만 본다.

### 5.2 DashboardView

표시:

- 내 사용량
- 버킷 수
- 최근 파일 작업
- 시스템 상태
- dashboard palette 패널 추가/숨김/삭제/크기 변경
- dashboard palette 패널 순서 버튼 이동과 drag-and-drop reorder
- dashboard palette catalog는 capacity, health, runtime, readiness, backup, I/O, audit request, sharing, quota, access key, identity, lifecycle, selected workspace, retention panel, execution-retention panel, storage-expansion panel을 제공
- dashboard palette catalog metadata는 `GET /api/dashboard/layout/widgets`에서 조회하고, 실패 시 frontend fallback catalog를 사용
- dashboard palette catalog와 저장 layout은 role 기준으로 필터링한다. `adminOnly` panel은 `ADMIN`에게만 노출하고, 직접 add 이벤트나 localStorage 복구에서도 현재 role이 볼 수 없는 panel은 제외한다.
- dashboard palette catalog는 `allowedRoles`와 `accessMode`를 함께 내려주며, frontend는 panel 설정 목록에 `Read-only`/`ADMIN only` access badge를 표시한다. 비관리자에게 보이는 dashboard panel은 요약 조회 중심이며 admin API 실행 버튼은 숨긴다.
- dashboard는 기본 조회 mode에서 widget metric만 보여주고, 편집 mode toggle을 켰을 때만 widget 추가/삭제/순서/section/preset/default assignment control을 노출한다.
- dashboard는 load 중 `dashboard-loading-state`, 실패 시 `dashboard-error-state`와 `dashboard-retry-button`, visible panel이 0개일 때 `dashboard-empty-state`를 표시한다. 자동 refresh는 background load로 처리해 기존 metric view를 흔들지 않는다.
- dashboard palette 추가 UI는 catalog `category` 기준으로 grouped select와 chip palette를 제공
- dashboard widget은 `overview`, `operations`, `governance` section에 배치할 수 있고 section별 metric band로 표시
- dashboard section은 위/아래 이동 버튼으로 순서를 바꿀 수 있고, widget order를 통해 서버 layout 저장 흐름에 보존
- dashboard section은 `Show/Hide`로 접고 펼칠 수 있으며 `sections[].collapsed` 값으로 서버 layout과 preset에 보존
- dashboard layout/preset payload는 `schemaVersion: osmu.dashboard-layout.v1`을 포함해 향후 layout schema migration 기준을 고정
- dashboard widget별 `options.tone`을 `default`/`focus`/`muted`로 전환해 중요한 panel을 강조하거나 낮은 우선순위 panel을 차분하게 표시
- dashboard widget별 `options.refreshInterval`은 `manual`/`30s`/`60s`/`5m`/`15m` 중 하나로 저장되며, dashboard 화면은 visible widget의 가장 짧은 자동 interval을 사용해 dashboard 데이터를 다시 조회한다.
- dashboard widget option control은 backend catalog의 `configOptions` schema를 기반으로 동적으로 렌더링
- Access Key dashboard widget은 active/total/provisioner 상태와 expired/expiring/unused key 요약을 표시
- Backup readiness panel은 `latestRestoreDrillEvidence`의 result, environment, recordedAt을 표시해 Kubernetes DR finalizer 또는 restore drill evidence API 제출 결과를 대시보드에서 바로 확인할 수 있게 한다.
- Readiness panel은 `OPERATIONS` category 항목이 있을 때 operations evidence gaps 요약과 `Operations` 빠른 필터 버튼을 표시해 operations readiness report, operations evidence plan, evidence plan invocation, invocation unblock plan, workflow run id plan, artifact import pending, operations finalizer pending, evidence handoff를 다른 warning 사이에서 바로 찾을 수 있게 한다. Pending check가 remediation metadata를 포함하면 로컬 명령, workflow path, `gh workflow run` 명령, evidence path, note를 접힌 보조 정보처럼 작은 코드/텍스트 블록으로 표시하고 command/workflow command copy 버튼을 제공해 운영자가 CLI 보고서를 열지 않아도 다음 evidence run을 바로 복사할 수 있게 한다. `OPERATIONS_EVIDENCE_PLAN` 항목이 있으면 summary 안에 plan 상태와 action count를 한 줄로 노출하고, `operationsEvidencePlan.actions` 상위 항목을 `readiness-evidence-plan-actions` list로 표시해 실행 순서, 입력 placeholder, 승인 필요 여부, kubeconfig 필요 여부, 복사 가능한 recommended command를 바로 확인할 수 있게 한다. `OPERATIONS_EVIDENCE_PLAN_INVOCATION` 항목과 `operationsEvidenceInvocation.actions`가 있으면 invocation 결과, planned/blocked/failed count, action별 block reason, unresolved placeholder, 복사 가능한 dispatch command를 보여줘 live workflow 실행 전 누락 조건을 UI에서 확인할 수 있게 한다. `OPERATIONS_INVOCATION_UNBLOCK_PLAN` 항목과 `operationsInvocationUnblockPlan.actions`가 있으면 required confirmation, placeholder input mapping, ambiguous placeholder warning, copyable confirmed/blocked-only/action plan command를 보여줘 workflow dispatch 전에 운영자가 무엇을 채워야 하는지 UI에서 정리할 수 있게 한다. `OPERATIONS_WORKFLOW_RUN_ID_PLAN` 항목과 `operationsWorkflowRunIdPlan.workflows`가 있으면 workflow query-required/ready 상태, workflow별 `gh run list` query command, artifact collection plan follow-up command, security evidence finalizer command를 보여줘 workflow dispatch 후 run id 수집 단계를 추적할 수 있게 한다.
- Artifact collection visibility: `operationsArtifactCollectionPlan`이 있으면 readiness panel은 collection result, ready/missing artifact count, Operations Readiness Artifact Finalizer command, local import command, 상위 artifact별 `gh run download` command를 표시한다. Secret rotation, commercial integration, commercial approval, operations handoff package, Kubernetes operations report sync artifact가 포함되면 같은 목록에서 target evidence, approval evidence, handoff evidence, deployed dashboard sync evidence 다운로드/가져오기 경로도 확인할 수 있다. 이로써 live workflow dispatch 이후 run id를 채우고 artifact import로 넘어가는 단계를 dashboard에서 바로 추적할 수 있다.
- Evidence handoff visibility: `operationsEvidenceHandoff`가 있으면 readiness panel은 현재 bottleneck result, next step code, blocked/missing count, 복사 가능한 next command, 상위 stage 상태를 표시한다. 이로써 운영자는 Markdown 보고서를 열기 전에도 지금 당장 `invoke-operations-evidence-plan.ps1`, run id collection, artifact finalizer, artifact import 중 어느 단계로 가야 하는지 확인할 수 있다.
- Dispatch preflight visibility: `operationsDispatchPreflight`가 있으면 readiness panel은 result, selected/failed/missing/warning count, required GitHub secrets, ready plan command, execute command, preflight check rows, required input rows, workflow file rows를 표시한다. 이로써 운영자는 `-Execute`를 붙이기 전 누락된 confirmation, placeholder, workflow file, secret name 상태를 dashboard에서 확인할 수 있다.
- Artifact import visibility: `operationsReadinessArtifactImport`가 있으면 readiness panel은 import result/status, selected group count, imported/failed count, secret policy, entry별 source/destination path와 detail을 표시한다. 이로써 운영자는 artifact finalizer 이후 어떤 evidence file이 promote됐고 어떤 파일이 실패했는지 dashboard에서 확인할 수 있다.
- Operations finalizer visibility: `operationsReadinessFinalize`가 있으면 readiness panel은 finalizer result, readiness result, failed/gap count, secret masking policy, 상위 command, 상위 step result를 표시한다. 이로써 운영자는 artifact import 이후 combined operations readiness finalizer가 어떤 하위 finalizer를 선택했고 마지막 readiness 재생성 결과가 무엇인지 dashboard에서 확인할 수 있다.
- Operations handoff package visibility: `operationsHandoffPackage`가 있으면 readiness panel은 package result, target environment/cluster/operator, failed/planned/check count, secret policy, 상위 check 상태를 표시한다. 이로써 운영자는 최종 handoff package evidence가 runbook/troubleshooting/rollback/support/known-gap 검토까지 통과했는지 dashboard에서 바로 확인할 수 있다.
- Operations convergence visibility: `operationsReadinessConvergence`가 있으면 readiness panel은 ready/action-required result, current bottleneck, readiness/finalizer result, stage readiness, no-execute safety policy, 상위 recommended command rows를 표시한다. 이로써 운영자는 handoff, readiness, finalizer report를 따로 열기 전에 지금 전체 operations workflow가 ready로 수렴했는지 또는 어떤 command chain이 남았는지 dashboard에서 확인할 수 있다.
- Access Key 목록은 All/Active/Expired/Expiring/Unused/Inactive 필터를 제공
- 내장 layout preset 조회/선택/적용. Built-in presets: `operations`, `compact`, `admin`, `operator`, `executive`, `storage-ops`, `security-audit`.
- `operator` preset은 day-two 운영자용 기본 preset으로 readiness convergence, backup evidence, storage expansion, execution retention, live I/O, health/runtime, access key, quota, lifecycle, selected workspace를 operations 중심으로 배치한다.
- ADMIN custom layout preset 저장/수정/삭제/내보내기/가져오기
- ADMIN ROLE/ORGANIZATION별 dashboard 기본 preset 지정/해제
- 로그인 사용자는 dashboard layout을 서버에 저장하고, 비로그인 상태에서는 localStorage fallback을 사용

관리자 표시:

- 전체 사용자 수
- 전체 버킷 수
- 전체 사용량
- 최근 감사 로그

### 5.3 DeveloperPage

표시:

- Access Key 발급 form.
- bucket scope 선택.
- READ/WRITE/DELETE/ADMIN permission 선택.
- 생성된 Secret Key 1회 표시.
- 기존 Access Key 목록과 비활성화 action.
- 개발자 시작 checklist로 endpoint, bucket, access key, SDK 예제 준비 상태와 진행률 표시.
- S3 compatible endpoint summary.
- S3 compatible endpoint summary는 `GET /api/developer/s3-client-config` 응답을 사용해 endpoint, region, signature version, virtual-hosted-style domain suffix를 표시한다.
- AWS CLI, AWS SDK JavaScript, boto3 Python, AWS SDK Java, MinIO Client snippets are generated from endpoint, region, and selected bucket for replacement-use setup.
- Real S3 client compatibility matrix는 AWS CLI, MinIO Client, boto3, AWS SDK JavaScript/Java를 기본 대상으로 하고, s3fs-fuse/goofys, s3cmd는 고객 전환 시나리오가 있을 때 후보 상태, 인증 방식, 검증 operation, 필수 option을 표시한다.
- 선택 bucket context.

접근:

- `ADMIN`, `ORG_ADMIN`, `USER` 모두 접근 가능.
- 개발자 login mode와 `USER` fallback은 `/developer`로 이동한다.
- `/admin`, `/audit` 접근 권한이 없는 사용자는 `/developer` 또는 role fallback route로 이동한다.

- ADMIN custom dashboard preset bundle export/import UI를 제공해 고객사별 대시보드 구성을 JSON 묶음으로 옮길 수 있음
- `/admin`에서 API 작업이 실패하면 전역 오류 아래 `admin-action-remediation-panel`을 표시한다. 패널은 `ApiClientError.status`, `code`, `requestId`를 보존하고 `AUTHENTICATION_REQUIRED`, `AUTHORIZATION_FAILED`, `VALIDATION_ERROR`, `NOT_FOUND`, `CONFLICT`, 기타 실패별로 세션 재로그인, 권한/scope 확인, 입력값 수정, 목록 새로고침, 감사 로그 확인 같은 다음 조치를 안내한다.
- AdminPage는 role별 panel 노출을 parent level에서 제한한다. `ADMIN`은 object share policy/analytics, quota policy, lifecycle/retention, storage expansion runner 같은 global operations panel과 billing pricing policy save를 볼 수 있고, `ORG_ADMIN`은 Access Key, 선택 bucket 권한/metadata, 자기 조직 사용자/조직/팀 관리, billing pricing policy read-only preview만 본다. `admin-role-restricted-panel-list`는 숨겨진 global operations 영역을 고정 selector로 표시한다.
- BillingChargebackPanel은 `getBillingPricingPolicyProposals`, `createBillingPricingPolicyProposal`, `approveBillingPricingPolicyProposal`, `approveBillingPricingPolicyProposalPriceList` wrapper로 ADMIN-only pricing proposal queue와 commercial price-list approval reference를 표시한다. `billing-pricing-policy-proposal-approve-button`은 내부 chargeback 계산 정책 승인용이고, `billing-pricing-policy-price-list-approve-button`은 법무/상업 승인 참조 기록용이다.
- `admin-approval-workflow-panel`은 Storage Profile `PENDING/APPROVED` 요청과 Storage Expansion `PLANNED/APPROVED` 요청을 한 큐로 묶어 승인, 반려, dry-run 계획, 적용 단계를 보여준다. 각 row는 `admin-approval-profile-*`, `admin-approval-expansion-*` 버튼으로 기존 admin API action을 재사용한다.
- `admin-security-audit-policy-panel`은 Access Key hygiene, 공유 링크 보호 정책, quota 정책 coverage, lifecycle conflict, enterprise auth plan, audit failure 상태를 한 화면에 정리한다. `getEnterpriseAuthPlan`으로 `GET /api/admin/security/enterprise-auth-plan`을 읽고, `LOCAL_PASSWORD` active / OIDC, LDAP planned / role-org-team claim mapping을 `admin-security-policy-row`에 표시한다. `previewEnterpriseAuthClaims`는 admin-only `POST /api/admin/security/enterprise-auth/claim-preview` wrapper로 sample OIDC claim mapping과 audit evidence contract를 고정하고, `provisionEnterpriseAuthUser`는 `POST /api/admin/security/enterprise-auth/jit-provision` wrapper로 admin-approved JIT apply contract를 고정한다. `getOidcAuthorizationRequest`는 public `GET /api/auth/oidc/authorize` wrapper로 OIDC authorization URL start contract를 고정하고, `completeOidcCallback`은 `GET /api/auth/oidc/callback?code&state` wrapper로 callback/token exchange 결과를 기존 login response contract에 맞춰 받는다. `loginWithLdap`은 `POST /api/auth/ldap/login` wrapper로 LDAP bind/search 결과를 기존 login response contract에 맞춰 받는다. `admin-security-audit-open-audit-link`로 `/audit` 상세 필터/CSV 화면으로 이동하며, `admin-security-policy-row`는 보안 정책별 상태와 근거를 고정 selector로 노출한다.
- ADMIN Storage Expansion panel은 요청 capacity, server count, PV/server, reason을 입력해 MinIO pool 증설 계획을 만들고 `PLANNED/APPROVED/REJECTED/APPLIED` 상태를 관리함

### 5.4 BucketListView

기능:

- 버킷 목록 조회
- 버킷 생성
- user/organization bucket owner 선택
- 버킷 삭제
- 사용량 표시
- S3 직접 업로드 이후 사용량 동기화
- 권한 표시
- 관리 가능한 bucket의 `READ`, `WRITE`, `DELETE`, `ADMIN` 권한 부여/회수
- Bucket permission subject selector는 `USER`, `ORGANIZATION`, `TEAM`을 지원하며, TEAM 선택 시 팀 목록을 사용한다.

### 5.5 ObjectExplorerView

기능:

- prefix 기반 탐색
- prefix 입력/초기화
- object key 검색
- 검색어 match highlight
- object tag 입력/수정/표시/filter
- object tag 형식/길이 사전 검증
- object metadata 상세 패널
- object metadata index/storage drift 상태 표시
- object metadata ETag/checksum index/storage 비교 표시
- object version 목록 패널과 version restore 버튼
- object version 목록 패널과 version restore 버튼
- presigned upload URL 생성 시 object tag 전달
- delimiter 기반 폴더형 prefix 이동
- prefix breadcrumb 버튼 이동
- `nextCursor` 기반 다음 파일 로드
- object list page size 선택
- 파일 목록
- 파일 업로드
- 128 MiB 이상 파일은 multipart upload API를 자동 사용
- 파일 다운로드
- 파일 삭제
- 업로드 진행률/전송 bytes 표시와 중복 업로드 방지
- 업로드 취소와 마지막 업로드 재시도
- 빈 상태 표시

Soft delete UI:

- Object Explorer는 `Active`/`Trash` segmented control을 제공한다.
- `Active` 목록의 Delete는 object를 trash로 이동한다.
- `Trash` 목록은 deleted object와 `deletedAt`을 표시한다.
- `Trash` 목록에서 Restore와 Purge를 실행할 수 있다.
- Admin dashboard는 trash retention days, batch size, purge success/failure metric을 표시하고 수동 `Run purge`를 실행할 수 있다.
- Admin dashboard lifecycle 영역에서 retention enabled, retention days, batch size를 변경하고 `Save`로 저장할 수 있다.
- Admin dashboard lifecycle 영역은 version retention days, version batch size, purged version count도 함께 표시/저장한다.
- Admin dashboard lifecycle 영역에서 retention enabled, retention days, batch size를 변경하고 `Save`로 저장할 수 있다.
- Admin dashboard는 Storage Expansion execution output retention 상태(pending/redacted/failed)를 표시하고 수동 `Run retention`을 실행할 수 있다.
- Admin dashboard는 `GET /api/admin/storage-expansion/summary` aggregate를 사용해 Storage Expansion 요청 open/applied/rejected 수, open capacity, 전체 execution 수, 실패/timeout 실행 수, 최근 요청/실행을 `storage-expansion` palette panel로 표시한다.

Version UI:

- Object version panel provides version Download/Restore/Delete actions.
- Download saves the selected historical bytes without changing active object.
- Delete removes only the selected historical version and refreshes dashboard usage.

### 5.6 AccessKeyView

기능:

- Access Key 목록
- Access Key 생성
- Access Key 만료일 입력
- Access Key 발급에는 최소 1개 bucket scope와 permission이 필요하다는 안내 표시
- Bucket scope 선택
- `READ`, `WRITE`, `DELETE` permission 선택
- 여러 bucket scope를 누적해 하나의 Access Key 발급
- bucket별 scope/permission 표시
- 마지막 사용 시각 `lastUsedAt` 표시
- S3 API 인증 성공 누적 횟수 `usageCount` 표시
- Access Key usage analysis panel로 총 S3 사용 횟수, 사용된 key 수, 최근 사용 시각, 최다 사용 key 표시
- 만료 시각 `expiresAt` 표시
- Secret rotation grace 만료 시각 `rotationGraceExpiresAt` 표시
- expired/expiring/never-used/stale 상태별 운영 조치 hint 표시
- 생성된 policy 이름 표시
- Secret Key 1회 표시와 재조회 불가/분실 시 rotate 필요 안내
- Secret Key rotate 버튼
- Access Key 비활성화 버튼
- Dashboard Access Key widget에 만료됨, 7일 이내 만료 예정, 미사용/장기 미사용 key 수 표시
- Access Key 목록 필터로 expired/expiring/unused key만 빠르게 확인
- Access Key 목록의 운영 조치 hint는 만료 active key는 비활성화, 만료 임박 key는 rotate, never-used/stale key는 owner 확인 후 비활성화를 제안
- Access Key bulk cleanup 버튼은 expired active key와 never-used/stale active key 후보를 `POST /api/access-keys/bulk-disable`로 일괄 비활성화
- Access Key bulk cleanup 실행 전 preview 목록으로 후보 key 이름, id, 조치 label, 사유를 표시하고 후보별 checkbox로 일괄 비활성화 포함/제외를 선택
- Access Key bulk cleanup preview는 secret 값을 제외한 JSON 파일로 export할 수 있어 승인/검토 기록에 첨부 가능하며 selected/excluded 후보를 함께 기록

- Access Key scope builder exposes `READ`, `WRITE`, `DELETE`, and `ADMIN` permission checkboxes.

### 5.7 AdminUserView

기능:

- 사용자 목록
- 사용자 생성
- 사용자 생성 시 조직 선택
- ORG_ADMIN에게 자기 조직 사용자 관리 화면 표시
- 사용자 비활성화
- 역할 변경

### 5.8 AdminOrganizationView

기능:

- 조직 목록
- 조직 생성
- 기본 쿼터 표시
- 조직별 사용량, bucket count, object count 표시
- ORG_ADMIN에게 자기 조직 usage 표시. `BillingChargebackPanel`도 `getBillingPricingPolicy`, `getChargebackPreview`, `downloadChargebackPreviewCsv` 결과를 사용하지만 저장 버튼은 ADMIN에게만 보이고, preview/export는 자기 조직 scope만 표시해야 한다.
- 사용자 생성 화면과 조직 선택 연동

- Admin can delete empty organizations with a confirm dialog.

### 5.9 AdminQuotaPolicyView

기능:

- `USER`, `ORGANIZATION`, `BUCKET` target quota policy 목록 표시
- target type 선택 후 users/organizations/buckets 목록에서 target 선택
- target 검색 입력으로 긴 user/organization/bucket 목록 필터링
- quota GiB 입력 후 정책 저장
- quota policy 변경 사유 reason 입력
- 기존 quota policy의 Edit 버튼으로 target과 quota를 form에 prefill하고 quota만 빠르게 수정
- target별 used bytes, quota bytes, remaining bytes 표시
- quota policy 변경 history에서 create/update/delete, 이전 quota, 신규 quota, actor, reason, 시각 표시
- quota policy 삭제 confirm dialog 연동

### 5.10 AdminAuditLogView

기능:

- 감사 로그 목록
- eventType 필터
- actor 필터
- requestId 필터
- targetType/targetId 필터
- result 필터
- 기간 필터
- limit 필터
- nextCursor 기반 다음 로그 로드

## 6. 상태 관리

MVP는 Vue `reactive` 기반 lightweight store를 사용한다.

```text
authStore: session/user/token, role computed, API token sync, sessionStorage token restore
```

확장 시 Pinia store로 분리한다.

```text
bucketStore
objectStore
accessKeyStore
adminStore
systemStore
```

## 7. API 클라이언트

공통 처리:

- baseURL
- JWT header
- JSON API, 파일 다운로드, 파일 업로드 401 refresh retry 처리
- refresh 실패 시 token/session state와 화면 데이터를 정리하고 `session-expired` 또는 `session-invalid` 사유를 auth store와 login redirect query로 전달
- 새로고침 시 sessionStorage token을 복구하고 `/api/users/me`로 사용자 정보를 재확인
- 에러 응답 변환
- 에러 응답의 `requestId`를 alert에 표시해 운영 문의와 감사 로그 추적에 사용
- 파일 업로드 progress
- 파일 업로드 abort signal과 재시도 상태
- multipart upload part PUT 병렬 전송, ETag 수집, complete API 호출
- Browser는 CORS에 노출된 `ETag` header만 읽을 수 있으므로 MinIO bucket CORS `ExposeHeaders`에 `ETag`가 필요하다.
- multipart upload 실패/취소 시 abort API best-effort 호출

## 8. MVP 구현 순서

1. 기존 Vue 예제 화면 제거
2. 기본 레이아웃 생성
3. API client 생성
4. DashboardView
5. BucketListView
6. ObjectExplorerView
7. LoginView
8. AccessKeyView
9. Admin 화면

## 9. UX 원칙

- 대용량 파일 업로드 상태를 표시한다.
- 128 MiB 이상 파일은 part별 presigned URL을 받아 제한된 동시성으로 병렬 업로드한다.
- 기본 multipart part 동시 업로드 수는 `VITE_MULTIPART_UPLOAD_CONCURRENCY=4`이며 client에서 1~8 범위로 제한한다.
- multipart part upload는 network error, 408, 429, 5xx 응답에 대해 jitter가 적용된 exponential backoff로 재시도한다. 기본값은 `VITE_MULTIPART_UPLOAD_PART_RETRIES=2`, `VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS=500`, `VITE_MULTIPART_UPLOAD_RETRY_JITTER_RATIO=0.25`이다.
- MinIO CORS가 `ETag`를 expose하지 않으면 multipart complete에 필요한 part ETag를 수집할 수 없으므로 업로드 실패로 처리한다.
- 대용량 파일 업로드 중 취소할 수 있고, 실패 또는 취소된 마지막 업로드는 같은 bucket/key/file로 재시도할 수 있다.
- multipart upload 실패/취소 시 미완료 part를 abort하도록 Backend에 정리 요청을 보낸다.
- tab close나 네트워크 완전 단절로 abort 요청이 전송되지 못하면 Backend cleanup scheduler가 만료 session을 `EXPIRED`로 전환하고 MinIO multipart upload를 abort한다.
- 버킷 삭제, 파일 삭제, 권한 회수, Access Key/사용자 비활성화는 확인 모달을 사용한다.
- 권한 없는 작업은 숨기거나 비활성화한다.
- 긴 파일명은 줄임 처리와 tooltip을 사용한다.
- 용량은 사람이 읽기 쉬운 단위로 표시한다.
- 오류 메시지는 짧고 원인 중심으로 표시한다.
- 서버 오류에는 `Request ID`를 함께 표시한다.

## Storage Expansion UI Update

- Server dry-run runner selector: `storage-expansion-dry-run-runner-button`. It calls the backend dry-run runner for `KUBECTL_DIFF` or `HELM_DIFF`; default disabled mode records `SKIPPED`.
- Server apply runner selectors: `storage-expansion-apply-run-type-select`, `storage-expansion-apply-runner-button`. Default disabled mode records `APPLY / SKIPPED`; enabled success updates the request to `APPLIED`.
- Server rollback runner selectors: `storage-expansion-rollback-type-select`, `storage-expansion-rollback-revision-input`, `storage-expansion-rollback-target-input`, `storage-expansion-rollback-runner-button`. Default disabled mode records `ROLLBACK / SKIPPED` for an `APPLIED` request.
- Runner preflight selectors: `storage-expansion-runner-preflight-panel`, `storage-expansion-runner-preflight-refresh-button`, `storage-expansion-runner-preflight-list`, `storage-expansion-runner-preflight-remediation`. It reads `GET /api/admin/storage-expansion/runner-preflight` and displays dry-run/apply/rollback/GitOps PR runner enablement, tool readiness, and remediation hints before any server command execution.

- Execution history row의 `storage-expansion-execution-apply-button`은 `SUCCESS`인 `APPLY` 또는 `GITOPS_PR` 기록에서만 활성화한다.
- 버튼 실행 시 `POST /api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply`를 호출하고, 실행 기록 기반 `appliedEvidence`를 자동 반영한다.
- Dry-run panel은 `storage-expansion-dry-run-type-select`, `storage-expansion-dry-run-result-select`, `storage-expansion-dry-run-output-input`으로 `KUBECTL_DIFF` 또는 `HELM_DIFF` evidence를 기록한다.
- Dry-run record selector: `storage-expansion-dry-run-record-button`, `storage-expansion-dry-run-url-input`, `storage-expansion-dry-run-notes-input`.
- GitOps draft panel은 PR URL, merge SHA, pipeline URL, notes 입력 후 `storage-expansion-gitops-pr-record-button`으로 `GITOPS_PR` 실행 이력을 기록한다.
- GitOps PR runner/evidence selector: `storage-expansion-gitops-pr-runner-button`, `storage-expansion-gitops-pr-url-input`, `storage-expansion-gitops-merge-sha-input`, `storage-expansion-gitops-pipeline-url-input`, `storage-expansion-gitops-notes-input`.

- ADMIN Storage Expansion panel은 요청별 MinIO Tenant patch와 Helm values patch preview를 표시한다.
- Preview YAML은 실제 적용 명령이 아니라 `referenceOnly` 검토용 산출물이다.
- Preview YAML은 tenant, helm values, bundle 단위로 다운로드할 수 있다.
- `APPROVED` 요청은 dry-run 실행 계획을 생성해 preflight checklist, artifact SHA-256, 추천 kubectl/helm 명령을 표시한다.
- `APPROVED` 요청은 GitOps draft를 생성해 브랜치명, 커밋 메시지, 변경 파일, review checklist, PR 본문을 표시하고, GitOps ZIP bundle을 내려받을 수 있다.
- 실행 이력 영역은 dry-run, GitOps PR, Helm diff, kubectl diff, apply, rollback 결과를 기록하고 목록으로 표시한다.
- GitOps PR runner 실행 이력의 `failureReason` 응답 필드 또는 notes의 `failureReason=...` 값이 있으면 `storage-expansion-execution-failure-reason` badge로 인증 실패, 권한 부족, branch protection, repository 설정 오류, timeout 같은 원인을 바로 표시한다.
- `APPLIED` 처리 전 적용 증거 URL/명령/티켓 ID를 `storage-expansion-apply-evidence-input`에 입력해야 한다.
- 안정 선택자: `storage-expansion-preview-button`, `storage-expansion-tenant-yaml`, `storage-expansion-helm-yaml`, `storage-expansion-download-tenant-button`, `storage-expansion-download-helm-button`, `storage-expansion-download-bundle-button`, `storage-expansion-execution-plan-button`, `storage-expansion-execution-plan-panel`, `storage-expansion-execution-commands`, `storage-expansion-gitops-plan-button`, `storage-expansion-gitops-plan-panel`, `storage-expansion-gitops-branch`, `storage-expansion-gitops-commit`, `storage-expansion-gitops-files`, `storage-expansion-gitops-review-list`, `storage-expansion-gitops-pr-body`, `storage-expansion-gitops-bundle-download-button`, `storage-expansion-execution-history-button`, `storage-expansion-execution-history-panel`, `storage-expansion-execution-record-form`, `storage-expansion-execution-history-list`, `storage-expansion-apply-evidence-input`.

