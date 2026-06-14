# OSMU Backup and Recovery

MVP drill runbook: `backup-restore-drill.md`.

이 문서는 OSMU 백업과 복구 전략을 정의한다.

## 1. 백업 대상

OSMU는 두 종류의 데이터를 가진다.

### 1.1 Metadata

저장 위치:

- MariaDB

대상:

- 사용자
- 조직
- 버킷 메타데이터
- 권한
- Access Key 메타데이터
- 쿼터
- 감사 로그
- 시스템 설정

### 1.2 Object Data

저장 위치:

- MinIO

대상:

- 영상
- 이미지
- 문서
- 로그 파일
- AI 학습 데이터
- 백업 파일

## 2. MVP 백업 전략

MVP에서는 자동 백업보다 복구 가능한 구조와 문서를 먼저 제공한다.

포함:

- MariaDB dump 가이드
- MinIO bucket replication 가이드
- MinIO object export 가이드
- 장애 시 복구 절차 문서

## 3. MariaDB 백업

기본 방식:

```text
mariadb-dump
```

백업 주기:

- 개발: 수동
- 운영: 매일 1회 이상

보관 정책:

- 일간 7일
- 주간 4주
- 월간 6개월

## 4. MinIO 백업

후보:

- MinIO replication
- `mc mirror`
- 외부 S3 호환 저장소 복제
- 원격 MinIO 클러스터 복제
- NAS 백업

MVP:

- `mc mirror` 기반 수동 백업 가이드

제품화:

- 버킷 단위 백업 정책
- 스케줄 백업
- 백업 상태 대시보드
- 실패 알림

## 5. 복구 시나리오

### 5.1 MariaDB 장애

1. 서비스 중지
2. MariaDB 복구
3. dump restore
4. Backend 실행
5. Health API 확인

### 5.2 MinIO 데이터 손실

1. 장애 버킷 확인
2. 백업 대상 확인
3. object restore
4. bucket metadata와 실제 object 정합성 확인

### 5.3 전체 서버 장애

1. 새 서버 준비
2. Docker Compose 또는 Kubernetes 배포
3. MariaDB 복구
4. MinIO 데이터 복구
5. Backend/Frontend 실행
6. API 검증

## 6. 복구 목표

초기 목표:

- RPO: 24시간
- RTO: 수동 복구 기준 4시간 이내

제품화 목표:

- RPO: 1시간 이내
- RTO: 1시간 이내

## 7. 향후 기능

- 백업 정책 UI
- 버킷별 백업 설정
- 외부 S3 백업
- 백업 상태 조회 API
- 백업 실패 알림
- 특정 시점 복구

