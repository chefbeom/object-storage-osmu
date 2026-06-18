# OSMU Storage Profile Design

Storage Profile is the bucket-level policy that tells OSMU what storage behavior the bucket is requesting. It is not a raw RAID controller inside one disk host. It is an OSMU control-plane feature that maps a bucket to MinIO pool/parity intent and leaves auditable request, approval, and apply history.

## Goal

- Let users request a bucket profile before storing data.
- Let admins approve, reject, and apply the profile.
- Support three MVP profiles: `PERFORMANCE`, `STANDARD`, `DURABLE`.
- Keep the profile visible in user and admin UI.
- Persist profile requests and assignments in MariaDB.
- Prepare a clean handoff to MinIO pool labels, storage class hints, and parity settings.

## Profile Catalog

| Code | Name | Alias | Goal | Risk | MinIO hint |
| --- | --- | --- | --- | --- | --- |
| `PERFORMANCE` | Performance | RAID0-like | Shard hot data across a performance pool for high throughput. | High | `PERFORMANCE`, low parity or dedicated fast pool |
| `STANDARD` | Standard | Erasure Coding | Balance throughput and durability. | Medium | Default erasure coding pool |
| `DURABLE` | Durable | High Parity | Prioritize durability over speed and storage efficiency. | Low | Higher parity or dedicated durable pool |

Important: `PERFORMANCE` means RAID0-like behavior at the object-storage placement/profile layer. If a disk or pool fails, data loss risk is higher than Standard/Durable. The UI and API must show this risk before approval.

## MVP User Flow

1. User logs in and selects a bucket.
2. User opens Storage page and sees the active profile. If no assignment exists, OSMU shows `STANDARD` as default.
3. User selects `PERFORMANCE`, `STANDARD`, or `DURABLE`, enters a reason, and submits a request.
4. Admin opens Admin page and sees the request queue.
5. Admin approves or rejects the request with an optional note.
6. Admin applies an approved request.
7. OSMU writes the active bucket assignment and marks the request `APPLIED`.

## Status Model

| Status | Meaning |
| --- | --- |
| `PENDING` | User request created, waiting for admin review. |
| `APPROVED` | Admin approved, not yet active. |
| `REJECTED` | Admin rejected. |
| `APPLIED` | Admin applied and bucket assignment changed. |

Rules:

- Only bucket managers can create requests for that bucket.
- Only `ADMIN` can approve, reject, or apply.
- Status can move from `PENDING` to `APPROVED` or `REJECTED`.
- Apply is allowed only from `APPROVED`.
- Requesting the currently active profile is rejected.
- `PERFORMANCE` requires a reason because of data-loss risk.

## REST API

User/API client:

- `GET /api/storage-profiles`
- `GET /api/storage-profile-requests`
- `GET /api/buckets/{bucketName}/storage-profile`
- `POST /api/buckets/{bucketName}/storage-profile-requests`

Admin:

- `GET /api/admin/storage-profile-requests`
- `PATCH /api/admin/storage-profile-requests/{requestId}/status`
- `POST /api/admin/storage-profile-requests/{requestId}/apply`

Request payload:

```json
{
  "requestedProfile": "PERFORMANCE",
  "reason": "video ingest needs RAID0-like throughput"
}
```

Admin status payload:

```json
{
  "status": "APPROVED",
  "adminNote": "approved for temporary media pool"
}
```

Current profile response:

```json
{
  "data": {
    "bucketName": "media",
    "assignment": {
      "bucketName": "media",
      "profile": {
        "code": "PERFORMANCE",
        "name": "Performance",
        "alias": "RAID0-like",
        "riskLevel": "HIGH",
        "poolSelector": "osmu.storage-profile=performance"
      },
      "appliedBy": "admin",
      "defaultProfile": false
    },
    "latestRequest": {
      "id": 1,
      "status": "APPLIED"
    }
  }
}
```

## MariaDB Schema

Migration: `V40__storage_profile_requests.sql`.

```sql
CREATE TABLE IF NOT EXISTS bucket_storage_profile_assignments (
    bucket_name VARCHAR(63) NOT NULL PRIMARY KEY,
    profile_code VARCHAR(32) NOT NULL,
    applied_by VARCHAR(128) NOT NULL,
    applied_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS storage_profile_requests (
    id BIGINT NOT NULL PRIMARY KEY,
    bucket_name VARCHAR(63) NOT NULL,
    current_profile_code VARCHAR(32) NOT NULL,
    requested_profile_code VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    reason VARCHAR(512) NULL,
    requested_by VARCHAR(128) NOT NULL,
    approved_by VARCHAR(128) NULL,
    approved_at TIMESTAMP NULL,
    applied_by VARCHAR(128) NULL,
    applied_at TIMESTAMP NULL,
    admin_note VARCHAR(512) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    KEY idx_storage_profile_requests_bucket (bucket_name, id),
    KEY idx_storage_profile_requests_status (status, id)
);
```

MVP notes:

- Assignment is keyed by bucket name because bucket names are globally unique in the current MVP.
- Request history is kept even if the active assignment changes later.
- Bucket deletion removes the active assignment. Request history may remain as audit history.

## MinIO Pool And Parity Mapping

Storage Profile should eventually map to MinIO Operator pool topology and/or storage class behavior.

| Profile | Pool selector | Parity direction | Operational meaning |
| --- | --- | --- | --- |
| `PERFORMANCE` | `osmu.storage-profile=performance` | Lowest allowed parity or dedicated low-parity pool | More disks/pods serve one object path in parallel. Speed first. |
| `STANDARD` | `osmu.storage-profile=standard` | Default erasure coding parity | General workload. Balanced speed and failure tolerance. |
| `DURABLE` | `osmu.storage-profile=durable` | Higher parity or stricter pool | More capacity overhead, slower writes, stronger durability. |

MVP implementation stores the selected profile and exposes MinIO hints. It does not yet move existing objects between pools or change live MinIO parity automatically. That follow-up needs a storage placement runner and a migration/rewrite workflow.

## Frontend MVP

User Storage page:

- Shows selected bucket active profile.
- Shows risk, alias, and MinIO binding hint.
- Lets user submit profile request.
- Shows recent requests for selected bucket.

Admin page:

- Shows all profile requests.
- Lets admin enter note.
- Lets admin approve, reject, or apply.

## Test Coverage

- Backend focused test: `StorageProfileControllerTest`.
- Frontend API wrapper test: `api-storage-profile.test.js`.
- Mock API supports the profile flow for frontend-only demo.

Remaining test work:

- Browser E2E for user request plus admin approve/apply.
- MariaDB integration smoke for migration `V40`.
- MinIO pool/parity runner tests after live placement is implemented.
