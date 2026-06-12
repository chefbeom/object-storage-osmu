# OSMU 문서 인덱스

OSMU 개발과 제품화를 위한 문서 목록이다.

## 1. 핵심 기준 문서

| 문서 | 목적 |
| --- | --- |
| `PROJECT_MEMORY.md` | 최종 목표와 장기 방향 |
| `PRODUCT_REQUIREMENTS.md` | PRD, MVP 요구사항, 기능 명세 |
| `planning-requirements.md` | 사용자 목표 기준 기획 요구사항 |
| `codingcovention.md` | 코딩 컨벤션 |

## 2. 개발 설계 문서

| 문서 | 목적 |
| --- | --- |
| `system-architecture.md` | 전체 시스템 구조 |
| `api-spec.md` | REST API 명세 |
| `database-design.md` | MariaDB 테이블 설계 |
| `backend-design.md` | Spring Boot 백엔드 설계 |
| `frontend-design.md` | Vue 프론트엔드 설계 |
| `local-dev-env.md` | 로컬 개발 환경 설계 |

## 3. 운영/제품화 문서

| 문서 | 목적 |
| --- | --- |
| `security-design.md` | 인증, 권한, 키, 보안 정책 |
| `backup-recovery.md` | 백업과 복구 전략 |
| `operation-monitoring.md` | 로그, 메트릭, 알림, 운영 기준 |
| `deployment-strategy.md` | Docker Compose, Kubernetes, Helm 배포 전략 |
| `test-strategy.md` | 테스트 범위와 검증 전략 |
| `test-cases.md` | 기능별 테스트 케이스 |
| `development-roadmap.md` | MVP부터 최종 제품까지 로드맵 |

## 4. 추천 읽기 순서

1. `PROJECT_MEMORY.md`
2. `planning-requirements.md`
3. `system-architecture.md`
4. `api-spec.md`
5. `database-design.md`
6. `backend-design.md`
7. `frontend-design.md`
8. `local-dev-env.md`
9. `security-design.md`
10. `backup-recovery.md`
11. `operation-monitoring.md`
12. `deployment-strategy.md`
13. `test-strategy.md`
14. `test-cases.md`
15. `development-roadmap.md`

## 5. 현재 기술 결정

- Backend: Spring Boot
- Frontend: Vue + Vite
- Metadata DB: MariaDB
- Object Storage: MinIO
- Local Infra: Docker Compose
- Production Target: Kubernetes + Helm
- API: REST API + S3 compatible API

## 6. 다음 작업 기준

코드 구현 전 최소 필요 문서:

- `api-spec.md`
- `database-design.md`
- `backend-design.md`
- `local-dev-env.md`

첫 구현 목표:

- MariaDB + MinIO 로컬 실행
- Backend health API
- MinIO 연결 확인 API
- Bucket API
- Object API
