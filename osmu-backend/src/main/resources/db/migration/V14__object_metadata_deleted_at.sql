ALTER TABLE object_metadata
    ADD COLUMN IF NOT EXISTS deleted_at DATETIME(6) NULL AFTER tags;

CREATE INDEX IF NOT EXISTS idx_object_metadata_deleted_at
    ON object_metadata (bucket_name, deleted_at);
