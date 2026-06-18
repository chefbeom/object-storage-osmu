## Object Lifecycle Rule Audit

- Lifecycle rule save/delete is ADMIN-only.
- Successful save writes `OBJECT_LIFECYCLE_RULE_SAVE` with target type `OBJECT_LIFECYCLE_RULE`.
- Successful delete writes `OBJECT_LIFECYCLE_RULE_DELETE` with target type `OBJECT_LIFECYCLE_RULE`.
- S3 lifecycle XML import writes `OBJECT_LIFECYCLE_S3_XML_IMPORT`.

## Access Key SigV4 Secret Handling

- New access keys store `secret_key_hash` for OSMU header-secret authentication and encrypted `secret_key_ciphertext` for AWS SigV4 verification.
- `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY` must be stable in each environment. If it changes, existing SigV4-enabled access keys must be re-issued or re-encrypted.
- Existing access keys with null `secret_key_ciphertext` remain usable with `X-OSMU-Secret-Key`, but cannot use SigV4 header auth.

## Secret And Certificate Rotation Policy

- Rotation policy draft: `secret-rotation-policy.md`.
- Real secret values must not be committed to git, worklogs, release reports, audit reports, screenshots, or logs.
- TLS certificate rotation uses the `osmu-tls` Kubernetes Secret contract from the ingress draft.
- JWT signing secret rotation invalidates active sessions.
- Access key encryption key rotation requires access key re-issue or re-encryption migration.

## Secret And Certificate Rotation Policy

- Rotation policy draft: `secret-rotation-policy.md`.
- Real secret values must not be committed to git, worklogs, release reports, audit reports, screenshots, or logs.
- TLS certificate rotation uses the `osmu-tls` Kubernetes Secret contract from the ingress draft.
- JWT signing secret rotation invalidates active sessions.
- Access key encryption key rotation requires access key re-issue or re-encryption migration.
# OSMU Security Design

이 문서는 OSMU 보안 설계를 정의한다.

상세 role, endpoint, dashboard panel 권한 표는 `iam-rbac-matrix.md`를 기준으로 한다. Kubernetes ServiceAccount와 cluster RBAC 권한 경계는 `kubernetes-rbac-matrix.md`를 기준으로 한다.

## 1. 보안 목표

- 기본 private 정책
- 인증된 사용자만 접근
- 권한 있는 사용자만 버킷/파일 조작
- Secret, Token, Password 보호
- 감사 로그 기반 추적성 확보

## 2. 인증

MVP:

- loginId/password 로그인
- JWT access token
- refresh token

현재 구현:

- bootstrap admin 계정을 in-memory 또는 MariaDB 사용자 저장소에 생성한다.
- bootstrap admin 비밀번호는 PBKDF2-SHA256 hash로 저장한다.
- access token과 refresh token은 HMAC SHA-256 서명 JWT로 발급한다.
- Health, Login, Refresh 외 `/api/**`는 Bearer access token을 검증한다.
- refresh token은 SHA-256 hash로 저장하고, refresh 성공 시 회전하며, logout 시 폐기한다.
- `/api/admin/**`는 기본적으로 `ADMIN` role만 접근할 수 있다.
- 예외적으로 `ORG_ADMIN`은 `AdminRbacPolicy`에 명시된 조직 스코프 API만 접근할 수 있다.
- `GET /api/users/me`는 JWT subject 기준 사용자 저장소를 조회한다.
- 일반 사용자는 본인이 소유한 bucket/object/access key만 조회하거나 변경할 수 있다.

향후:

- SSO
- LDAP
- Active Directory
- MFA

## 3. 인가

역할:

- `ADMIN`
- `ORG_ADMIN`
- `USER`

권한:

- `bucket:read`
- `bucket:write`
- `bucket:delete`
- `object:read`
- `object:write`
- `object:delete`
- `accessKey:manage`
- `admin:manage`

현재 구현:

- 관리자 API RBAC는 `AdminRbacPolicy`에서 중앙 관리한다.
- `ADMIN`은 모든 `/api/admin/**` API에 접근할 수 있다.
- `USER` 또는 알 수 없는 role은 모든 `/api/admin/**` API에서 차단된다.
- `ORG_ADMIN`은 자기 조직 사용자와 조직 usage만 볼 수 있다.
- `ORG_ADMIN`은 자기 조직 일반 `USER` 생성/비활성화만 가능하다.
- `ORG_ADMIN` 허용 route는 `GET/POST /api/admin/users`, `PATCH /api/admin/users/{userId}/status`, `GET /api/admin/organizations`, `GET /api/admin/organizations/usage`로 제한한다.
- `ORG_ADMIN`은 감사 로그, 전체 시스템 usage, system status, storage expansion, backup/restore drill, quota policy 같은 global admin API에는 접근할 수 없다.
- Dashboard widget catalog/layout/preset 응답은 role 기준으로 필터링한다. `adminOnly` dashboard panel은 `ADMIN`에게만 노출되며, `USER`와 `ORG_ADMIN`이 직접 저장 요청에 넣으면 `AUTHORIZATION_FAILED`로 차단한다.

## 4. 버킷 보안

- 기본 버킷은 private.
- Public bucket은 MVP에서 제외.
- 버킷 소유자는 기본 admin 권한.
- 조직/사용자 단위 권한 부여.
- `ORG_ADMIN`은 자기 조직 사용자와 조직 usage만 볼 수 있다.
- `ORG_ADMIN`은 자기 조직 일반 `USER` 생성/비활성화만 가능하다.
- `ORG_ADMIN`은 감사 로그, 전체 시스템 usage, system status 같은 global admin API에는 접근할 수 없다.

현재 구현:

- bucket 생성 시 `ownerType/ownerId`로 user 또는 organization owner를 저장한다.
- `ADMIN`은 전체 bucket을 조회/관리할 수 있다.
- 일반 `USER`는 본인 bucket만 목록/상세/object 작업 가능하다.
- `ORG_ADMIN`은 본인 조직의 `ORG` bucket을 생성/삭제할 수 있다.
- 같은 조직 사용자는 `ORG` bucket의 object 목록/업로드/다운로드/삭제에 접근할 수 있다.
- 같은 조직 일반 `USER`는 `ORG` bucket 자체 삭제 같은 관리 작업은 수행할 수 없다.
- `USER`, `ORGANIZATION`, `BUCKET` quota policy는 admin 전용 API로 관리한다.
- quota policy create/update/delete는 admin 전용 history에 이전 quota, 신규 quota, actor, 선택 입력한 변경 사유를 남긴다.
- `USER` bucket upload는 user quota policy를 초과할 수 없다.
- `ORG` bucket upload는 organization quota policy 또는 organization default quota를 초과할 수 없다.
- `BUCKET` quota policy가 있으면 bucket metadata quota보다 우선한다.
- `bucket_permissions` metadata로 `USER` 또는 `ORGANIZATION` subject에 `READ`, `WRITE`, `DELETE`, `ADMIN` 권한을 부여할 수 있다.
- `READ`는 object 목록/다운로드/presigned download, `WRITE`는 upload/presigned upload/complete, `DELETE`는 object 삭제를 허용한다.
- `ADMIN` bucket permission은 권한 관리와 object 작업 권한을 포함한다.
- bucket permission 부여/회수는 감사 로그 대상이다.
- Object share link 생성은 `READ` 권한이 필요하다.
- ADMIN global share policy can require password and IP allowlist on new object share links and cap expiry/download limits.
- Object share link password is optional and stored only as a SHA-256 hash bound to the token hash; missing or wrong password returns `404 NOT_FOUND`.
- Object share link IP allowlist is optional and accepts IP/CIDR literals only; blocked or invalid client IP returns `404 NOT_FOUND`.
- Admin share analytics exposes status/protection/download metadata but does not return raw share token or public URL.
- Share link public download는 Bearer token 없이 접근할 수 있으므로 opaque token은 32-byte random value로 만들고 DB에는 SHA-256 hash만 저장한다.
- Share link는 `ACTIVE`, `EXPIRED`, `REVOKED` 상태를 가지며 만료/취소 후 public download는 `404 NOT_FOUND`로 응답한다.
- Share link create/download/revoke는 audit log에 남겨 외부 공유 추적성을 확보한다.
- `ORG` bucket upload는 organization default quota를 초과할 수 없다.

## 5. Access Key 보안

- Secret Key는 생성 시 1회만 노출.
- Secret Key 원문 저장 금지.
- Access Key 비활성화 기능 제공.
- 키 생성/삭제는 감사 로그 대상.
- 키는 사용자와 연결된다.
- 키는 접근 가능한 bucket scope와 `READ`, `WRITE`, `DELETE` permission을 가진다.
- 사용자를 `INACTIVE` 또는 `LOCKED` 상태로 바꾸면 해당 사용자의 활성 Access Key도 비활성화한다.
- Bearer access token은 매 요청마다 DB 사용자 상태를 재확인하므로 비활성/잠금 사용자의 기존 access token도 즉시 거부한다.

현재 구현:

- access key는 생성한 user id와 연결된다.
- secret key 원문은 생성 응답에서만 반환하고, 서버에는 SHA-256 hash만 저장한다.
- secret key 원문, hash, ciphertext를 포함하는 access key record `toString()`은 민감값을 redaction한다.
- access key 생성 audit list/export에는 secret key 원문을 기록하지 않는다.
- access key 생성 시 선택 만료일 `expiresAt`을 지정할 수 있고, 과거 시각은 validation에서 거부한다.
- 만료된 access key는 S3 호환 API 인증과 secret rotation을 허용하지 않는다.
- access key secret rotation은 기존 key id/access key/scope를 유지하고 새 secret을 1회 반환한다.
- rotation 이후 기존 secret은 즉시 인증 실패 처리되며, `ACCESS_KEY_ROTATE` audit log에는 새 secret 원문을 기록하지 않는다.
- lightweight/local demo verifier는 access key secret redaction smoke를 실행하며, `-BackendLogPath` 입력 시 실제 backend log file에서도 생성된 secret 원문을 scan한다.
- `osmu.metadata.mode=in-memory`에서는 메모리에 저장하고, `mariadb`에서는 `access_keys` table에 저장한다.
- `ADMIN`은 전체 access key를 볼 수 있다.
- 일반 `USER`는 본인이 생성한 access key만 볼 수 있다.
- access key 생성 시 일반 `USER`는 본인이 접근 가능한 bucket만 `allowedBuckets`에 넣을 수 있다.
- access key 생성 시 `bucketScopes`로 bucket별 permission을 지정할 수 있다.
- access key 생성 시 요청 permission은 사용자가 해당 bucket에서 가진 `READ`, `WRITE`, `DELETE` 권한을 초과할 수 없다.
- access key 생성 시 Backend가 S3 IAM 호환 policy document를 생성한다.
- bucket permission 회수 시 영향을 받는 active access key의 bucket별 scope와 S3 policy를 재동기화한다.
- 재동기화 후 남은 scope가 없으면 access key를 `INACTIVE`로 바꾸고 S3 user/policy를 제거한다.
- S3 호환 API에서 Access Key 인증이 성공하면 `lastUsedAt`을 갱신해 미사용/장기 미사용 key 정리 근거로 사용한다.
- 생성된 policy document는 secret 값을 포함하지 않고 bucket ARN과 S3 action만 포함한다.
- `OSMU_ACCESS_KEY_PROVISIONING_MODE=minio`에서는 MinIO user/policy 적용을 시도한다.
- 현재 MinIO provisioner는 `mc admin user add`, `mc admin policy create`, `mc admin policy attach`를 호출한다.
- 사용자 비활성화/잠금 시 `AccessKeyService.deactivateByOwnerId`가 active key를 찾아 metadata status와 S3 provisioner 상태를 함께 비활성화한다.
- MinIO provisioning 성공 후에만 metadata 저장을 완료한다.
- metadata 저장 실패 시 이미 만든 MinIO user/policy를 제거한다.
- MinIO secret rotation 후 metadata 저장 실패 시, 기존 secret ciphertext가 있으면 provisioner secret rollback을 시도한다.
- 기본 `noop` 모드는 개발/테스트용이며 policy document만 생성한다.
- 운영 환경에서는 secret이 process argument에 노출되지 않는 native Admin API 또는 별도 provisioning worker로 교체하는 것이 목표다.

## 6. 비밀번호 보안

- 비밀번호 평문 저장 금지.
- bcrypt, argon2 등 안전한 password hashing 사용.
- 초기 임시 비밀번호는 변경 유도.

## 7. 로그 보안

로그에 남기면 안 되는 값:

- password
- secretKey
- access token
- refresh token
- Authorization header
- private credential

감사 로그에 남길 값:

- actorId
- actorRole
- eventType
- targetType
- targetId
- result
- ipAddress
- userAgent
- requestId
- createdAt

현재 구현:

- 감사 로그 actor는 JWT 인증 사용자 loginId를 사용한다.
- `X-Forwarded-For`가 있으면 첫 번째 IP를 `ipAddress`로 기록한다.
- `User-Agent`를 `userAgent`로 기록한다.
- `X-Request-Id` 또는 `X-Correlation-Id`를 `requestId`로 기록하고 `X-Request-Id` 응답 헤더로 전파한다.
- 요청에 request id가 없으면 Backend가 새 값을 생성해 request attribute, response header, error response body, audit log에 같은 값으로 사용한다.
- `osmu.metadata.mode=in-memory`에서는 메모리에 저장하고, `mariadb`에서는 `audit_logs` table에 저장한다.
- scheduler 같은 자동 작업은 `actorId = system`으로 감사 로그를 기록한다. 예: 만료 multipart cleanup은 `OBJECT_MULTIPART_UPLOAD_CLEANUP`, object retention purge는 `OBJECT_RETENTION_PURGE`, object version retention purge는 `OBJECT_VERSION_RETENTION_PURGE` event를 남긴다.

## 8. API 보안

- 모든 관리 API는 인증 필요.
- 모든 파일 API는 권한 검사 필요.
- Validation 실패 시 내부 구조 노출 금지.
- Storage error 상세 credential 노출 금지.

## 9. 네트워크 보안

운영 기본:

- TLS 적용
- Backend와 MinIO 내부망 통신
- MariaDB 외부 직접 노출 금지
- MinIO Console 관리자 접근 제한

## 9.1 Kubernetes RBAC Hardening

현재 Kubernetes/Helm draft는 backend, frontend, MariaDB, MinIO, backup workload에 전용 ServiceAccount를 사용하고 `automountServiceAccountToken: false`를 적용한다. 일반 애플리케이션 workload에는 Kubernetes `Role`, `ClusterRole`, `RoleBinding`, `ClusterRoleBinding`을 부여하지 않는다.

Storage Expansion in-cluster kubectl runner에는 별도 `osmu-storage-expansion-runner` ServiceAccount와 namespace-scoped Role/RoleBinding을 사용한다. 이 Role은 `Tenant/osmu-minio` patch/update와 legacy `StatefulSet/osmu-minio` rollback에 필요한 `get/patch/update` 중심 권한만 허용하며 Secret read, Pod exec, create/delete, cluster-scoped RBAC를 허용하지 않는다. Helm upgrade/rollback과 GitOps PR runner는 기본적으로 외부 GitOps/CI identity를 사용해야 하며, 더 넓은 chart-admin 권한이 필요하면 별도 리뷰와 verifier가 필요하다. 현재 권한 기준은 `kubernetes-rbac-matrix.md`와 `scripts/verify-kubernetes-rbac-matrix.ps1`로 검증한다.

운영 cluster에 RBAC를 적용한 뒤에는 `scripts/verify-storage-expansion-rbac-auth.ps1 -Namespace <namespace>`를 실행해 `kubectl auth can-i` evidence를 `.osmu-run/latest-storage-expansion-rbac-auth.json`에 남긴다. 이 evidence는 허용되어야 하는 Tenant/StatefulSet patch/update 권한과 거부되어야 하는 Secret read, Pod exec, create/delete, cluster-scoped RBAC 권한을 함께 확인한다.

MinIO Operator CRD와 대상 Tenant가 준비된 cluster에서는 `scripts/verify-storage-expansion-server-dry-run.ps1 -Namespace <namespace> -ImpersonateRunner`를 실행해 `.osmu-run/latest-storage-expansion-server-dry-run.json`에 server-side dry-run evidence를 남긴다. 이 evidence는 `tenants.minio.min.io` CRD 존재, 기존 `Tenant/osmu-minio` 존재, `kubectl apply --server-side --dry-run=server` 결과를 포함한다.

## 10. 보안 구현 순서

1. password hashing
2. JWT 인증
3. 사용자 생성/비활성화 API
4. Role check
5. Bucket permission check
6. Secret masking
7. Audit log
8. TLS guide
9. SSO/LDAP

## Storage Expansion Execution Log Masking

- Storage Expansion runner/manual/GitOps execution 저장 전 `command`, `output`, `notes`에 secret masking을 적용한다.
- masking 대상: password/passwd/secret/token/credential/access key/secret key key-value, `Authorization: Bearer|Basic`, S3 query signature/credential/security token, URL userinfo password.
- output retention limit 기본값은 `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_MAX_OUTPUT_CHARS=16384`이다.
- masking은 `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_MASKING_ENABLED=true`가 기본값이다. 운영 환경에서는 끄지 않는다.
- execution output retention은 `OSMU_STORAGE_EXPANSION_EXECUTION_LOG_RETENTION_ENABLED=true`가 기본값이며, 기본 90일이 지난 output만 redaction marker로 교체한다.
- GitOps PR runner는 기본 비활성(`OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_ENABLED=false`)이며 활성화 시 shell을 거치지 않고 `git`/`gh` executable을 직접 실행한다. runner preflight는 repository path의 `.git` metadata, `git -C {repositoryPath} status --short`, `gh auth status`를 확인한다. repository path는 운영자가 신뢰한 GitOps working tree로 제한해야 하며, 실행 결과는 sanitizer와 output retention 정책을 거친 execution history로 저장한다.
- GitOps PR runner artifact path는 repository root 내부로 normalize된 경우에만 쓸 수 있다. `../` 등으로 repository 밖을 가리키는 경로는 runner 실패로 처리한다.
- GitOps PR runner 실패 notes에는 `failureReason`을 남긴다. 인증 실패, 권한 부족, branch protection, dirty worktree, tool missing 등 운영자가 조치해야 하는 실패를 구분하는 데 사용한다.
- execution record, result, command, artifact SHA-256, audit trail은 유지해 운영 추적성을 보존한다.

## Object Retention Policy Audit

- retention policy 변경은 관리자 loginId로 `OBJECT_RETENTION_POLICY_UPDATE` 감사 로그를 기록한다.

