ALTER TABLE object_metadata
    ADD COLUMN etag VARCHAR(128) NOT NULL DEFAULT '' AFTER deleted_at;
