ALTER TABLE presigned_upload_sessions
    ADD COLUMN checksum_algorithm VARCHAR(32) NOT NULL DEFAULT '' AFTER storage_upload_id,
    ADD COLUMN checksum_type VARCHAR(32) NOT NULL DEFAULT '' AFTER checksum_algorithm;
