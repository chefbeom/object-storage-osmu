ALTER TABLE object_metadata
    ADD COLUMN user_metadata TEXT NULL AFTER checksums;

UPDATE object_metadata
SET user_metadata = '{}'
WHERE user_metadata IS NULL;

ALTER TABLE object_metadata
    MODIFY COLUMN user_metadata TEXT NOT NULL;

ALTER TABLE object_versions
    ADD COLUMN user_metadata TEXT NULL AFTER tags;

UPDATE object_versions
SET user_metadata = '{}'
WHERE user_metadata IS NULL;

ALTER TABLE object_versions
    MODIFY COLUMN user_metadata TEXT NOT NULL;
