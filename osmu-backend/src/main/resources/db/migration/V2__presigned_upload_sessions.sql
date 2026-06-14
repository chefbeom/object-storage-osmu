CREATE TABLE IF NOT EXISTS presigned_upload_sessions (
    upload_id VARCHAR(64) NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    bucket_name VARCHAR(63) NOT NULL,
    object_key VARCHAR(1024) NOT NULL,
    status VARCHAR(32) NOT NULL,
    previous_size_bytes BIGINT NOT NULL,
    previous_exists BOOLEAN NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP NULL,
    INDEX idx_presigned_upload_sessions_user_id (user_id),
    INDEX idx_presigned_upload_sessions_status (status),
    INDEX idx_presigned_upload_sessions_expires_at (expires_at)
);
