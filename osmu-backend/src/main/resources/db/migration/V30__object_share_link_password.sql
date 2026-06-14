ALTER TABLE object_share_links
    ADD COLUMN IF NOT EXISTS password_hash VARCHAR(64) NULL AFTER token_hash;
