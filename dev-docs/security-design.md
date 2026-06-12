# OSMU Security Design

이 문서는 OSMU 보안 설계를 정의한다.

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

## 4. 버킷 보안

- 기본 버킷은 private.
- Public bucket은 MVP에서 제외.
- 버킷 소유자는 기본 admin 권한.
- 조직/사용자 단위 권한 부여.

## 5. Access Key 보안

- Secret Key는 생성 시 1회만 노출.
- Secret Key 원문 저장 금지.
- Access Key 비활성화 기능 제공.
- 키 생성/삭제는 감사 로그 대상.
- 키는 사용자와 연결된다.

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
- createdAt

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

## 10. 보안 구현 순서

1. password hashing
2. JWT 인증
3. Role check
4. Bucket permission check
5. Secret masking
6. Audit log
7. TLS guide
8. SSO/LDAP

