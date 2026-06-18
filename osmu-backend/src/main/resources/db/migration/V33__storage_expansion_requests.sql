CREATE TABLE IF NOT EXISTS storage_expansion_requests (
    id BIGINT NOT NULL PRIMARY KEY,
    requested_capacity_bytes BIGINT NOT NULL,
    server_count INT NOT NULL,
    volumes_per_server INT NOT NULL,
    volume_size_bytes BIGINT NOT NULL,
    estimated_raw_capacity_bytes BIGINT NOT NULL,
    estimated_usable_capacity_bytes BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL,
    reason VARCHAR(512) NULL,
    created_by VARCHAR(128) NOT NULL,
    applied_by VARCHAR(128) NULL,
    applied_at TIMESTAMP NULL,
    applied_evidence VARCHAR(512) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    KEY idx_storage_expansion_status (status, id),
    KEY idx_storage_expansion_created_at (created_at)
);

ALTER TABLE storage_expansion_requests ADD COLUMN IF NOT EXISTS applied_by VARCHAR(128) NULL;
ALTER TABLE storage_expansion_requests ADD COLUMN IF NOT EXISTS applied_at TIMESTAMP NULL;
ALTER TABLE storage_expansion_requests ADD COLUMN IF NOT EXISTS applied_evidence VARCHAR(512) NULL;
