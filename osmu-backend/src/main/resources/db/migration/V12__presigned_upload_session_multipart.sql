ALTER TABLE presigned_upload_sessions
    ADD COLUMN upload_mode VARCHAR(32) NOT NULL DEFAULT 'PRESIGNED_PUT' AFTER tags,
    ADD COLUMN storage_upload_id TEXT NULL AFTER upload_mode,
    ADD COLUMN expected_size_bytes BIGINT NOT NULL DEFAULT 0 AFTER storage_upload_id;
