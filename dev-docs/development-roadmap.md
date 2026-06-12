# OSMU Development Roadmap

이 문서는 OSMU의 MVP부터 최종 제품까지 개발 로드맵을 정의한다.

## 1. 최종 목표

OSMU는 기업이 자체 인프라에서 운영할 수 있는 S3 호환 프라이빗 오브젝트 스토리지 플랫폼이다.

최종 제품은 다음을 제공한다.

- 대용량 파일 저장
- REST API
- S3 호환 API
- Web Portal
- FUSE Mount 연동
- 사용자/조직/권한 관리
- Access Key 관리
- 쿼터
- 감사 로그
- 백업/복구
- 모니터링
- Kubernetes 배포
- B2B 설치/운영 문서

## 2. Phase 0 - 문서와 기준 정리

목표:

- 제품 목표 확정
- 요구사항 정리
- 설계 문서 작성

산출물:

- `PROJECT_MEMORY.md`
- `PRODUCT_REQUIREMENTS.md`
- `planning-requirements.md`
- `api-spec.md`
- `database-design.md`
- `backend-design.md`
- `frontend-design.md`
- `local-dev-env.md`

## 3. Phase 1 - Local Infra + Backend Skeleton

목표:

- 로컬 실행 기반 완성
- Backend가 MariaDB/MinIO에 연결

작업:

- Docker Compose
- MariaDB
- MinIO
- Backend dependency 추가
- Health API
- Storage Health API
- Database Health API

완료 기준:

- `docker compose up -d`
- Backend 실행
- `/api/health` 정상
- `/api/storage/health` 정상
- `/api/database/health` 정상

## 4. Phase 2 - Bucket/Object MVP

목표:

- 실제 파일 저장 흐름 완성

작업:

- Bucket API
- Object API
- MinIO Adapter
- 기본 AuditLog
- 기본 Frontend 화면

완료 기준:

- 버킷 생성 가능
- 파일 업로드 가능
- 파일 다운로드 가능
- 파일 삭제 가능
- Vue 화면에서 목록 확인 가능

## 5. Phase 3 - Auth/User/Access Key

목표:

- 사용자 기반 제품 구조 완성

작업:

- 로그인
- JWT
- 사용자 관리
- 조직 관리
- Access Key 발급
- 기본 권한

완료 기준:

- 로그인 가능
- 사용자별 버킷 접근 가능
- Access Key 발급 가능

## 6. Phase 4 - Quota/Audit/Admin

목표:

- 기업 관리 기능 강화

작업:

- 사용자별 쿼터
- 버킷별 쿼터
- 감사 로그 조회
- 관리자 대시보드
- 사용량 통계

완료 기준:

- 사용량 확인 가능
- 쿼터 초과 차단
- 주요 이벤트 감사 로그 기록

## 7. Phase 5 - Operation MVP

목표:

- 운영 가능한 형태로 정리

작업:

- Docker Compose 정리
- README 작성
- API 문서 보강
- 설치 가이드
- 테스트 전략 반영
- 기본 모니터링

완료 기준:

- 새 환경에서 문서만 보고 실행 가능
- 기본 장애 확인 가능

## 8. Phase 6 - Kubernetes Productization

목표:

- B2B 설치형 제품 기반 마련

작업:

- Kubernetes manifests
- Helm Chart
- Ingress
- TLS guide
- MinIO Operator 검토
- Prometheus/Grafana 연동

## 9. Phase 7 - Backup/Security Advanced

목표:

- 제품 신뢰도 강화

작업:

- 백업 정책
- 외부 S3 백업
- 원격 클러스터 복제
- SSO/LDAP
- 고급 권한 정책
- 보안 가이드

## 10. Phase 8 - B2B Ready

목표:

- 판매 가능한 제품 형태

작업:

- 설치 마법사
- 라이선스 관리
- 관리자 문서
- 사용자 문서
- 운영자 문서
- 데모 시나리오
- 고객사별 설정 템플릿

## 11. 다음 즉시 작업

1. API 명세 최종 검토
2. DB 설계 최종 검토
3. Docker Compose 작성
4. Backend dependency 추가
5. Health API 구현

