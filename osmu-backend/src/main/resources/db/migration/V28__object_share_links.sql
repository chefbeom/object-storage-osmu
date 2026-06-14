CREATE TABLE IF NOT EXISTS object_share_links (
    id BIGINT NOT NULL PRIMARY KEY,
    token_hash VARCHAR(64) NOT NULL,
    bucket_name VARCHAR(63) NOT NULL,
    object_key VARCHAR(1024) NOT NULL,
    created_by_user_id BIGINT NOT NULL,
    status VARCHAR(16) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    note VARCHAR(512) NULL,
    created_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP NULL,
    UNIQUE KEY uk_object_share_links_token_hash (token_hash),
    KEY idx_object_share_links_bucket_key (bucket_name, object_key(255), id),
    KEY idx_object_share_links_status_expires (status, expires_at)
);
