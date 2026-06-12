# OSMU Operation and Monitoring

이 문서는 OSMU 운영, 로그, 메트릭, 알림 기준을 정의한다.

## 1. 운영 목표

- 서비스 상태를 빠르게 파악한다.
- 장애 원인을 추적할 수 있게 한다.
- 용량 부족을 미리 감지한다.
- 보안 이벤트를 추적한다.

## 2. Health Check

필수 API:

- `GET /api/health`
- `GET /api/database/health`
- `GET /api/storage/health`
- `GET /api/admin/system/status`

## 3. 로그

### 3.1 Application Log

포함:

- requestId
- method
- path
- status
- latency
- userId
- errorCode

제외:

- password
- secretKey
- token
- Authorization header

### 3.2 Audit Log

대상:

- 로그인 성공/실패
- 사용자 생성/비활성화
- 버킷 생성/삭제
- 파일 업로드/다운로드/삭제
- Access Key 생성/삭제
- 권한 변경
- 쿼터 변경

## 4. 메트릭

Backend:

- request count
- request latency
- error count
- active users
- bucket count
- object operation count

MariaDB:

- connection count
- query latency
- storage usage
- replication status optional

MinIO:

- disk usage
- bucket usage
- object count
- request count
- error count
- node health

## 5. 대시보드

MVP:

- Backend up/down
- MariaDB up/down
- MinIO up/down
- 전체 사용량
- 버킷 수
- 사용자 수

제품화:

- 조직별 사용량
- 버킷별 사용량
- 사용자별 트래픽
- API latency p95/p99
- 에러 추세
- 백업 상태

## 6. 알림

알림 조건:

- Backend down
- MariaDB down
- MinIO down
- 디스크 사용률 80% 이상
- 디스크 사용률 90% 이상
- API error 급증
- 백업 실패
- 인증 실패 급증

## 7. 도구

MVP:

- Spring Boot Actuator
- MinIO Console
- Application logs

제품화:

- Prometheus
- Grafana
- AlertManager
- Loki optional

## 8. 운영 문서

추후 작성:

- 설치 가이드
- 운영 가이드
- 장애 대응 가이드
- 백업/복구 가이드
- 업그레이드 가이드

