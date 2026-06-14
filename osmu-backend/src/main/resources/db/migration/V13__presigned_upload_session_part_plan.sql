ALTER TABLE presigned_upload_sessions
    ADD COLUMN part_size_bytes BIGINT NOT NULL DEFAULT 0 AFTER expected_size_bytes,
    ADD COLUMN part_count INT NOT NULL DEFAULT 0 AFTER part_size_bytes;
