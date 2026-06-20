# OSMU IAM/RBAC Matrix

이 문서는 OSMU의 현재 role, 관리자 API, dashboard panel, resource scope 권한을 한 곳에 고정한다.

목적은 다음 세 가지다.

- 신규 운영 API가 생겼을 때 누구에게 노출되는지 명확히 검토한다.
- Backend RBAC, Frontend panel visibility, API 문서가 서로 어긋나지 않게 한다.
- B2B/운영 환경에서 보안 리뷰와 감사 대응에 사용할 기준표를 제공한다.

## 1. Role Definition

| Role | 성격 | 현재 범위 |
| --- | --- | --- |
| `ADMIN` | 전역 시스템 관리자 | 모든 `/api/admin/**`, 전체 bucket/object/access key, dashboard admin panel |
| `ORG_ADMIN` | 조직 관리자 | 자기 조직 사용자/조직 usage/chargeback preview/alerts/notification preview/outbox/export/draft invoice export, pricing policy 조회, 자기 조직 bucket 관리, 일반 사용자 생성/비활성화 |
| `AUDITOR` | 읽기 전용 감사자 | 감사 로그, 운영 상태, dashboard summary/readiness, backup status 조회 |
| `USER` | 개발자/일반 사용자 | 본인 또는 허용된 bucket/object/access key, developer S3 client flow |

현재 구현에는 `STORAGE_ADMIN`, `SECURITY_ADMIN` 같은 추가 세분화 role이 없다. 이 role들은 후속 설계 후보이며, 추가 시 `AdminRbacPolicy`, dashboard widget matrix, frontend navigation, API spec을 함께 갱신해야 한다.

## 2. Admin API Matrix

| Area | Endpoint pattern | `ADMIN` | `ORG_ADMIN` | `AUDITOR` | `USER` | Scope rule | Enforcement |
| --- | --- | --- | --- | --- | --- | --- | --- |
| User list | `GET /api/admin/users` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 사용자만 조회 | `AdminRbacPolicy`, `AdminUserController.canView` |
| User create | `POST /api/admin/users` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 `USER`만 생성. `ADMIN`만 `AUDITOR` 생성 가능 | `AdminRbacPolicy`, `AdminUserController.resolveCreateOrganization`, `validateCreateRole` |
| User status | `PATCH /api/admin/users/{userId}/status` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 일반 `USER`만 관리, 자기 자신/관리자/AUDITOR role 차단 | `AdminRbacPolicy`, `AdminUserController.assertCanManage` |
| Organization list | `GET /api/admin/organizations` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직만 조회 | `AdminRbacPolicy`, `AdminOrganizationController.visibleOrganizations` |
| Organization usage | `GET /api/admin/organizations/usage` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 usage만 조회 | `AdminRbacPolicy`, `AdminOrganizationController.visibleOrganizations` |
| Billing pricing policy read | `GET /api/admin/billing/pricing-policy` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 preview 계산용 read-only 정책만 조회 | `AdminRbacPolicy`, `AdminBillingController` |
| Billing pricing policy save | `PUT /api/admin/billing/pricing-policy` | Allow | Deny | Deny | Deny | global chargeback 기본 rate 저장은 `ADMIN` 전용 | `AdminRbacPolicy`, `AdminBillingController`, `BillingPricingPolicyService` |
| Billing pricing policy proposal approval | `GET/POST /api/admin/billing/pricing-policy-proposals`, `POST /api/admin/billing/pricing-policy-proposals/{proposalId}/approve`, `POST /api/admin/billing/pricing-policy-proposals/{proposalId}/commercial-approval` | Allow | Deny | Deny | Deny | ADMIN-only internal chargeback pricing proposal/approval plus commercial price-list approval reference. `APPROVED_APPLIED` updates the internal calculation policy; `PRICE_LIST_APPROVED` records external commercial/legal approval reference without calling payment or notification adapters | `AdminRbacPolicy`, `AdminBillingController`, `BillingPricingPolicyService` |
| Chargeback preview | `GET /api/admin/billing/chargeback-preview` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 chargeback preview만 조회 | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback threshold alerts | `GET /api/admin/billing/chargeback-alerts` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 chargeback threshold alert만 조회 | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback alert notification preview | `GET /api/admin/billing/chargeback-alert-notifications/preview` | Allow | Allow | Deny | Deny | threshold alert와 같은 scope로 외부 알림 payload를 preview하며 실제 전송은 하지 않음 | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback alert notification outbox | `GET/POST /api/admin/billing/chargeback-alert-notifications/outbox`, `POST /api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-result`, `POST /api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-send` | Allow | Queue/List only | Deny | Deny | threshold alert와 같은 scope로 delivery outbox/history를 기록/조회하며 adapter result/retry state 기록과 configured notification webhook send는 `ADMIN`만 수행. preview/queue는 전송하지 않고, webhook 구성이 없으면 send/worker는 blocked state로 기록 | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback preview CSV export | `GET /api/admin/billing/chargeback-preview/export.csv` | Allow | Allow | Deny | Deny | preview와 같은 query/policy/scope를 CSV로 export | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback invoice draft CSV export | `GET /api/admin/billing/chargeback-invoice-draft/export.csv` | Allow | Allow | Deny | Deny | preview와 같은 query/policy/scope를 draft invoice CSV로 export하며 확정 청구서는 아님 | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback invoice draft persistence | `GET/POST /api/admin/billing/chargeback-invoice-drafts`, `POST /api/admin/billing/chargeback-invoice-drafts/{invoiceId}/approve` | Allow | Deny | Deny | Deny | ADMIN-only internal invoice draft persistence/approval. `APPROVED_INTERNAL` is the gate before final invoice creation | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Chargeback final invoice/payment workflow | `POST /api/admin/billing/chargeback-invoice-drafts/{invoiceId}/finalize`, `GET /api/admin/billing/chargeback-invoices`, `POST /api/admin/billing/chargeback-invoices/{invoiceId}/payment-request`, `GET/POST /api/admin/billing/chargeback-invoices/{invoiceId}/payment-provider-handoff`, `GET /api/admin/billing/chargeback-payment-provider-handoffs`, `POST /api/admin/billing/chargeback-payment-provider-handoffs/{handoffId}/adapter-result`, `POST /api/admin/billing/chargeback-invoices/{invoiceId}/payment-record` | Allow | Deny | Deny | Deny | ADMIN-only final invoice, payment state workflow, no-send payment provider handoff outbox, and adapter result/retry state. It stores product-side legal billing state and manual payment reference without invoking external payment providers | `AdminRbacPolicy`, `AdminBillingController`, `ChargebackPreviewService` |
| Team management | `GET/POST /api/admin/teams`, `PUT /api/admin/teams/{teamId}/members`, `DELETE /api/admin/teams/{teamId}` | Allow | Allow | Deny | Deny | `ORG_ADMIN`은 자기 조직 팀과 같은 조직 멤버만 관리 | `AdminRbacPolicy`, `AdminTeamController` |
| Organization create/delete | `POST /api/admin/organizations`, `DELETE /api/admin/organizations/{id}` | Allow | Deny | Deny | Deny | 전역 tenant 구조 변경 | `AdminRbacPolicy`, controller admin check |
| Audit | `GET /api/admin/audit-logs`, `GET /api/admin/audit-logs/export.csv` | Allow | Deny | Allow | Deny | 전역 감사 로그 read-only | `AdminRbacPolicy` |
| Usage/status | `GET /api/admin/usage`, `GET /api/admin/system/status`, `GET /api/admin/security/enterprise-auth-plan`, `GET /api/admin/dashboard/*` | Allow | Deny | Allow | Deny | 전역 운영/보안 plan 상태 read-only | `AdminRbacPolicy`, `AdminEnterpriseAuthPlanController` |
| Enterprise auth claim preview | `POST /api/admin/security/enterprise-auth/claim-preview` | Allow | Deny | Deny | Deny | OIDC sample claim은 PII를 포함할 수 있으므로 admin-only preview/audit | `AdminRbacPolicy`, `AdminEnterpriseAuthPlanController`, `OidcClaimPreviewService` |
| Enterprise auth JIT apply | `POST /api/admin/security/enterprise-auth/jit-provision` | Allow | Deny | Deny | Deny | 신규 local user 생성과 privileged role 승인이 가능하므로 admin-only apply/audit | `AdminRbacPolicy`, `AdminEnterpriseAuthPlanController`, `OidcJitProvisioningService` |
| Quota policy | `/api/admin/quota-policies/**` | Allow | Deny | Deny | Deny | 전역 quota 정책과 history | `AdminRbacPolicy` |
| Object share policy | `/api/admin/object-share-policy`, `/api/admin/object-share-analytics` | Allow | Deny | Deny | Deny | 전역 공유 정책/분석 | `AdminRbacPolicy` |
| Lifecycle/retention admin | `/api/admin/object-lifecycle/**`, `/api/admin/object-retention/**` | Allow | Deny | Deny | Deny | 전역 lifecycle/retention 운영 | `AdminRbacPolicy` |
| Storage expansion | `/api/admin/storage-expansion/**` | Allow | Deny | Deny | Deny | MinIO pool/PV/GitOps 증설 운영 | `AdminRbacPolicy`, `StorageExpansionService.requireAdmin` |
| Backup/restore drill | `GET /api/admin/backup/status`, `GET /api/admin/backup/restore-drill-evidence`, `POST /api/admin/backup/restore-drill-evidence` | Allow | Deny | GET only | Deny | 백업 준비도와 복구 증거. `AUDITOR`는 조회만 가능 | `AdminRbacPolicy` |

기본 원칙: `/api/admin/**`는 `ADMIN` 전용이다. `ORG_ADMIN` 허용 route는 위 표의 사용자/조직 조회 및 자기 조직 사용자 관리 API뿐이며, `AUDITOR` 허용 route는 감사/상태/backup evidence 조회 API뿐이다.

## 3. Non-Admin Resource Scope Matrix

| Resource | `ADMIN` | `ORG_ADMIN` | `USER` | Enforcement |
| --- | --- | --- | --- | --- |
| User bucket | 전체 조회/관리 | 본인이 가진 bucket permission 범위 | 본인 소유 bucket 조회/관리 | `BucketService` |
| Organization bucket | 전체 조회/관리 | 자기 조직 `ORG` bucket 생성/삭제/관리 | 같은 조직 object 작업 가능, bucket 관리 작업 제한 | `BucketService`, bucket permission checks |
| Object read | 전체 가능 | 조직/permission 범위 | 소유/permission 범위 | `ObjectService`, `BucketService` |
| Object write/delete | 전체 가능 | 조직/permission 범위 | 소유/permission 범위 | `ObjectService`, quota checks |
| Bucket permission | 전체 가능 | 자기 조직 `USER`/`ORGANIZATION`/`TEAM` subject 중심으로 제한 | bucket admin permission 없으면 제한 | `BucketPermissionRepository`, `BucketService` |
| Access key list | 전체 가능 | 현재는 본인 key 중심 | 본인 key만 | `AccessKeyService` |
| Access key create | 접근 가능한 bucket scope만 | 접근 가능한 bucket scope만 | 접근 가능한 bucket scope만 | `AccessKeyService`, S3 policy generator |
| S3 SigV4/API key | key scope 기준 | key scope 기준 | key scope 기준 | `S3RequestAuthService`, `AccessKeyService` |

## 4. Dashboard Panel Matrix

| Widget group | Widget ids | `ADMIN` | `ORG_ADMIN` | `AUDITOR` | `USER` | Catalog access | Enforcement |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Common storage | `capacity`, `remaining`, `buckets`, `objects`, `health`, `runtime`, `readiness`, `backup`, `io`, `selected` | Show | Show | Show | Show | `allowedRoles=["ADMIN","ORG_ADMIN","AUDITOR","USER"]`, `accessMode=read-only` | `DashboardLayoutService.widgetCatalog`, `HomeView.dashboardWidgetCatalogForCurrentRole` |
| Access key operations | `access-keys` | Show | Show | Show | Show | `allowedRoles=["ADMIN","ORG_ADMIN","AUDITOR","USER"]`, `accessMode=read-only`; data API scope still applies | `AccessKeyService`, dashboard summary scope |
| Audit read-only | `requests` | Show | Hide | Show | Hide | `allowedRoles=["ADMIN","AUDITOR"]`, `accessMode=read-only` | `DashboardLayoutService.isWidgetAllowedForUser`, frontend role filter |
| Admin operations | `sharing`, `quota`, `identity`, `lifecycle`, `retention`, `execution-retention`, `storage-expansion` | Show | Hide | Hide | Hide | `allowedRoles=["ADMIN"]`, `accessMode=admin-only` | `DashboardLayoutService.isWidgetAllowedForUser`, frontend role filter |

Dashboard server policy:

- `GET /api/dashboard/layout/widgets` returns only widgets visible to the current role.
- Catalog items include `allowedRoles` and `accessMode` so frontend/test verifiers can compare panel visibility with this matrix.
- `GET /api/dashboard/layout/presets` filters preset widgets by current role.
- `GET /api/dashboard/layout` removes widgets no longer visible to the current role.
- `PUT /api/dashboard/layout` rejects widgets outside the current role's `allowedRoles` with `AUTHORIZATION_FAILED`.

Frontend policy:

- Sidebar navigation hides Admin/Audit pages by role. `AUDITOR` sees Dashboard and Audit only.
- AdminPage hides global operations panels at parent component level with `isAdmin`; `ORG_ADMIN` keeps only org-scoped identity controls, access keys, and bucket-scoped permission/metadata panels.
- Dashboard palette uses backend catalog metadata.
- Fallback catalog, localStorage recovery, and direct add events all pass through the current role-visible catalog.
- Panel edit list displays the catalog access mode. Non-admin dashboard panels are read-only summaries; admin operation triggers stay hidden unless the user is `ADMIN`.

## 5. Kubernetes And Operations Matrix

Kubernetes ServiceAccount와 cluster RBAC 권한 경계는 `kubernetes-rbac-matrix.md`를 기준으로 한다.

| Operation | Current role | Reason | Evidence |
| --- | --- | --- | --- |
| MinIO pool/server pool expansion request | `ADMIN` | Adds pod/PV capacity and GitOps/Kubernetes artifacts | `/api/admin/storage-expansion/**` |
| Storage expansion apply/rollback/GitOps runner | `ADMIN` | Mutates infrastructure and can run external tooling | `StorageExpansionService.requireAdmin`, runner preflight |
| Backup status read | `ADMIN` | Includes global durability posture | `/api/admin/backup/status` |
| Restore drill evidence write | `ADMIN` | Records operational DR evidence and audit event | `/api/admin/backup/restore-drill-evidence` |
| Secret/certificate rotation | `ADMIN` plus external operator | Requires cluster secret changes | `secret-rotation-policy.md` |
| HA/DR runbook execution | `ADMIN` plus external operator | Impacts data durability and failover | `backup-restore-drill.md`, future HA/DR runbook |

## 6. Required Update Rule

다음 중 하나가 바뀌면 이 문서와 verifier를 같이 갱신한다.

- 새로운 `/api/admin/**` endpoint 추가
- role 추가 또는 role 이름 변경
- dashboard widget 추가 또는 `adminOnly` 정책 변경
- storage expansion, backup, restore, HA/DR 운영 API 변경
- access key scope, bucket permission, S3 호환 인증 정책 변경

## Additional Chargeback Admin Route

- Chargeback adapter retry worker: `GET /api/admin/billing/chargeback-adapter-retry-worker/status`, `POST /api/admin/billing/chargeback-adapter-retry-worker/run` are `ADMIN` only. `ORG_ADMIN`, `AUDITOR`, and `USER` are denied. `ChargebackAdapterRetryWorkerService` performs dry-run state inspection, attempts configured notification webhook delivery on run, and keeps payment-provider rows no-send/blocked without storing secrets or raw provider responses.

## 7. Verification Evidence

현재 검증 항목:

- `AdminRbacPolicyTest`: role별 admin route 허용/차단.
- `AdminEnterpriseAuthPlanControllerTest`, `EnterpriseAuthPlanServiceTest`, `OidcClaimPreviewServiceTest`, `OidcJitProvisioningServiceTest`, `OidcLoginServiceTest`, `LdapLoginServiceTest`: local-only enterprise auth plan, OIDC/LDAP readiness, OIDC claim preview/audit, admin-approved JIT apply, OIDC callback state/token/JWKS 검증, LDAP bind/search adapter, role/org/team claim mapping 검증.
- `AdminBillingControllerTest`, `ChargebackPreviewServiceTest`: `ADMIN`/`ORG_ADMIN` chargeback preview/export/draft invoice export/threshold alert/notification preview/outbox scope, ADMIN-only notification/payment adapter result retry state, invoice draft persistence/internal approval/final invoice/payment workflow/payment provider handoff outbox and pricing policy proposal approval, pricing policy save/defaulting, data-flow event cost pre-model, unsupported role denial 검증.
- `AdminTeamControllerTest`: `ADMIN`/`ORG_ADMIN` 팀 관리 scope와 팀 삭제 cleanup 검증.
- `BucketObjectFlowTest.teamBucketPermissionAppliesToTeamMembers`: `TEAM` subject bucket permission과 Access Key 재동기화 검증.
- `AdminUserControllerTest`: `USER`/`ORG_ADMIN`의 global admin API 차단.
- `DashboardLayoutControllerTest`: non-admin dashboard admin-only widget 숨김/저장 차단.
- `HomeView.test.js`: frontend role-aware dashboard filtering source contract.
- `scripts/verify-iam-rbac-matrix.ps1`: 이 문서와 코드/프론트 계약의 핵심 문자열 동기화.
