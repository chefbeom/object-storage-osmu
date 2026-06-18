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
