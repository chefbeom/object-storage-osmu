CREATE TABLE IF NOT EXISTS quota_policies (
    id BIGINT NOT NULL PRIMARY KEY,
    target_type VARCHAR(32) NOT NULL,
    target_id BIGINT NOT NULL,
    quota_bytes BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    UNIQUE KEY uk_quota_target (target_type, target_id)
);
