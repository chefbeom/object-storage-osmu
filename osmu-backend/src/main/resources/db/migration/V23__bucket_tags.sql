CREATE TABLE IF NOT EXISTS bucket_tags (
    bucket_name VARCHAR(63) NOT NULL,
    tag_key VARCHAR(128) NOT NULL,
    tag_value VARCHAR(256) NOT NULL,
    PRIMARY KEY (bucket_name, tag_key),
    INDEX idx_bucket_tags_key_value (tag_key, tag_value),
    CONSTRAINT fk_bucket_tags_bucket
        FOREIGN KEY (bucket_name) REFERENCES buckets(name)
        ON DELETE CASCADE
);
