CREATE TABLE IF NOT EXISTS object_metadata_tags (
    bucket_name VARCHAR(63) NOT NULL,
    object_key_hash CHAR(64) NOT NULL,
    tag_key VARCHAR(255) NOT NULL,
    tag_value VARCHAR(256) NOT NULL,
    PRIMARY KEY (bucket_name, object_key_hash, tag_key),
    INDEX idx_object_metadata_tags_lookup (bucket_name, tag_key, tag_value, object_key_hash),
    INDEX idx_object_metadata_tags_object (bucket_name, object_key_hash)
);
