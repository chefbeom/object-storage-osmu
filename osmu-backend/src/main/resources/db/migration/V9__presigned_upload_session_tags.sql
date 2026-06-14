ALTER TABLE presigned_upload_sessions
    ADD COLUMN tags TEXT NULL AFTER object_key;
