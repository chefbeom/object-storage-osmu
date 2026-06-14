CREATE TABLE IF NOT EXISTS bucket_permissions (
    id BIGINT NOT NULL PRIMARY KEY,
    bucket_id BIGINT NOT NULL,
    subject_type VARCHAR(32) NOT NULL,
    subject_id BIGINT NOT NULL,
    permission VARCHAR(32) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE KEY uk_bucket_permission (bucket_id, subject_type, subject_id, permission),
    INDEX idx_bucket_permissions_subject (subject_type, subject_id),
    CONSTRAINT fk_bucket_permissions_bucket
        FOREIGN KEY (bucket_id) REFERENCES buckets(id)
);
