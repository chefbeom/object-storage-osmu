ALTER TABLE object_metadata
    ADD COLUMN checksums TEXT NULL AFTER deleted_at;

UPDATE object_metadata
SET checksums = '{}'
WHERE checksums IS NULL;

ALTER TABLE object_metadata
    MODIFY COLUMN checksums TEXT NOT NULL;
