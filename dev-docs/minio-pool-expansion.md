# MinIO Pool Expansion Design

이 문서는 OSMU의 MinIO 저장소 확장 방향을 정의한다.

## 1. 결정 사항

OSMU의 운영형 MinIO 확장은 **Pod + PV를 server pool 단위로 추가하는 방식**을 기본 전략으로 한다.

선택한 방향:

- 기본 저장소는 MinIO distributed/erasure coding 구성을 목표로 한다.
- 용량 부족 시 기존 Pod에 임의 PV를 하나씩 붙이지 않는다.
- 단순히 StatefulSet `replicas`만 늘리지 않는다.
- 새 용량은 `server pool` 단위로 추가한다.
- 각 pool은 같은 크기의 Pod/PV 구성을 유지한다.

## 2. 권장 기본 구조

운영 기본값은 4개 이상의 MinIO server Pod를 권장한다.

```text
Pool 0
- minio-pool-0-0 + pv-0
- minio-pool-0-1 + pv-1
- minio-pool-0-2 + pv-2
- minio-pool-0-3 + pv-3
```

현재 개발 클러스터에는 `slave01`부터 `slave04`까지 worker node가 있으므로, 운영형 dev/staging 검증에서는 4개 Pod를 서로 다른 worker node에 분산하는 구성을 목표로 한다.

## 3. 용량 부족 시 확장 구조

기존 pool이 부족하면 같은 형태의 새 pool을 추가한다.

```text
Pool 0
- minio-pool-0-0 + pv-0
- minio-pool-0-1 + pv-1
- minio-pool-0-2 + pv-2
- minio-pool-0-3 + pv-3

Pool 1
- minio-pool-1-0 + pv-4
- minio-pool-1-1 + pv-5
- minio-pool-1-2 + pv-6
- minio-pool-1-3 + pv-7
```

이 방식은 용량과 처리량을 함께 늘릴 수 있다. 또한 pool 단위로 장애 도메인, 디스크 크기, 증설 기록을 관리하기 쉽다.

## 4. 피해야 할 방식

다음 방식은 기본 전략으로 사용하지 않는다.

- 기존 MinIO Pod 하나에 PV만 추가하는 방식
- 특정 PV 하나만 크게 확장하는 방식
- StatefulSet replica 수만 증가시키는 방식
- 서로 다른 크기의 PV를 같은 pool에 섞는 방식
- hostPath 기반 PV를 운영 저장소로 사용하는 방식

이 방식들은 erasure coding 균형, 장애 복구, 운영 자동화, 용량 예측을 어렵게 만든다.

## 5. 예외적으로 허용할 수 있는 방식

기존 PVC 용량 확장은 다음 조건에서만 단기 대응으로 허용한다.

- StorageClass가 volume expansion을 지원한다.
- 같은 pool의 모든 PVC를 같은 크기로 확장한다.
- 확장 전 백업/복구 가능성을 확인한다.
- 확장 후 MinIO health, OSMU bucket sync, S3 client smoke를 실행한다.

이 방식은 긴급 용량 확보에는 유용하지만, OSMU의 기본 확장 전략은 아니다.

## 6. OSMU 제품 기능으로 발전할 방향

OSMU는 장기적으로 Storage Expansion Manager를 제공한다.

목표 기능:

- MinIO pool별 raw/usable capacity 조회
- 사용량 70%, 80%, 90% threshold 알림
- 새 pool 추가 계획 생성
- 필요한 Pod/PV 수량과 예상 용량 계산
- MinIO Operator Tenant values 또는 manifest 생성
- 확장 전 backup/restore readiness gate 확인
- 확장 후 `mc admin info`, health check, S3 smoke 자동 실행
- 관리자 화면에서 확장 이력 확인

## 7. 운영 확장 절차 초안

1. 현재 사용량과 증가 추세를 확인한다.
2. MariaDB metadata backup과 MinIO object backup/replication 상태를 확인한다.
3. 새 worker node 또는 disk를 준비한다.
4. 새 PV 또는 StorageClass 용량을 준비한다.
5. MinIO Operator Tenant에 새 pool을 추가한다.
6. rollout 상태와 MinIO health를 확인한다.
7. OSMU backend `/api/storage/health`를 확인한다.
8. bucket create/delete smoke와 real S3 client smoke를 실행한다.
9. OSMU 문서와 worklog에 확장 결과를 기록한다.

## 8. 현재 MVP와의 차이

현재 `infra/k8s/minio.yaml`은 MVP 배포용 단일 MinIO StatefulSet이다.

```text
replicas: 1
args: server /data
volumeClaimTemplates: minio-data 1개
```

따라서 현재 매니페스트에서 바로 replica만 늘리는 것은 운영형 확장이 아니다. 운영형 확장은 MinIO Operator Tenant 또는 별도 distributed MinIO topology로 전환한 뒤 pool 단위로 진행한다.

## 9. 다음 구현 작업

- MinIO Operator 기반 Tenant manifest 초안 작성
- Helm values에 `minio.pools` 구조 추가
- `osmu-dev`에서 4 node distributed MinIO 검증 환경 준비
- 기존 단일 MinIO에서 운영형 MinIO로 이전하는 migration runbook 작성
- Storage Expansion Manager API/화면 요구사항 작성
