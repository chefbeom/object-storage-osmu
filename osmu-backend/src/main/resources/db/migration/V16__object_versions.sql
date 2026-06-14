CREATE TABLE IF NOT EXISTS object_versions (
  bucket_name VARCHAR(63) NOT NULL,
  object_key_hash CHAR(64) NOT NULL,
  object_key VARCHAR(1024) NOT NULL,
  version_id VARCHAR(64) NOT NULL,
  storage_key VARCHAR(1200) NOT NULL,
  size_bytes BIGINT NOT NULL,
  content_type VARCHAR(255) NOT NULL,
  object_last_modified_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  tags TEXT NOT NULL,
  PRIMARY KEY (bucket_name, object_key_hash, version_id),
  KEY idx_object_versions_object (bucket_name, object_key_hash, created_at)
);
