# OSMU Deployment Strategy

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

