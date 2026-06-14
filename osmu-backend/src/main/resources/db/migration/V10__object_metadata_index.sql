CREATE TABLE IF NOT EXISTS object_metadata (
    bucket_name VARCHAR(63) NOT NULL,
    object_key_hash CHAR(64) NOT NULL,
    object_key VARCHAR(1024) NOT NULL,
    size_bytes BIGINT NOT NULL,
    content_type VARCHAR(255) NOT NULL,
    last_modified_at TIMESTAMP NOT NULL,
    tags TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (bucket_name, object_key_hash),
    INDEX idx_object_metadata_bucket_key (bucket_name, object_key(255)),
    INDEX idx_object_metadata_bucket_updated (bucket_name, updated_at)
);
