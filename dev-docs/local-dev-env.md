# OSMU Local Development Environment

이 문서는 OSMU 로컬 개발 환경 설계를 정의한다.

## 1. 목표

개발자가 같은 환경에서 OSMU를 실행할 수 있게 한다.

로컬 환경은 다음을 제공한다.

- MariaDB
- MinIO
- MinIO Console
- Backend
- Frontend

## 2. 포트

| 서비스 | 포트 | 설명 |
| --- | --- | --- |
| Backend | 8080 | Spring Boot API |
| Frontend | 5173 | Vite Dev Server |
| MariaDB | 3306 | Metadata DB |
| MinIO API | 9000 | S3 API |
| MinIO Console | 9001 | MinIO Web Console |

## 3. Docker Compose 구성

예정 파일:

```text
infra/local/docker-compose.yml
infra/local/.env.example
```

서비스:

- `mariadb`
- `minio`

추후 선택:

- `prometheus`
- `grafana`

## 4. 환경변수

### MariaDB

```text
MARIADB_DATABASE=osmu
MARIADB_USER=osmu
MARIADB_PASSWORD=osmu-password
MARIADB_ROOT_PASSWORD=root-password
```

### MinIO

```text
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
```

### Backend

```text
SPRING_DATASOURCE_URL=jdbc:mariadb://localhost:3306/osmu
SPRING_DATASOURCE_USERNAME=osmu
SPRING_DATASOURCE_PASSWORD=osmu-password
OSMU_STORAGE_ENDPOINT=http://localhost:9000
OSMU_STORAGE_ACCESS_KEY=minioadmin
OSMU_STORAGE_SECRET_KEY=minioadmin
```

## 5. 실행 순서

1. Docker 실행
2. `docker compose up -d`
3. MariaDB 연결 확인
4. MinIO Console 접속
5. Backend 실행
6. Frontend 실행

## 6. 검증 명령

예정:

```text
GET http://localhost:8080/api/health
GET http://localhost:8080/api/database/health
GET http://localhost:8080/api/storage/health
```

MinIO Console:

```text
http://localhost:9001
```

## 7. 개발 데이터

초기 seed:

- admin user
- default organization
- sample bucket optional

## 8. 로컬 환경 원칙

- Secret은 `.env.example`에는 샘플만 둔다.
- 실제 `.env`는 Git에 커밋하지 않는다.
- 컨테이너 volume을 사용해 데이터 유지 가능하게 한다.
- reset 방법을 문서화한다.

## 9. 첫 구현 체크리스트

- `infra/local/docker-compose.yml`
- `infra/local/.env.example`
- MariaDB volume
- MinIO volume
- Backend profile `local`
- application-local.yaml
- Health API

