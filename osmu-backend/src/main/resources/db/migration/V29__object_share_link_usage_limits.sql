ALTER TABLE object_share_links
    ADD COLUMN IF NOT EXISTS max_downloads INT NULL AFTER note,
    ADD COLUMN IF NOT EXISTS download_count BIGINT NOT NULL DEFAULT 0 AFTER max_downloads,
    ADD COLUMN IF NOT EXISTS last_accessed_at TIMESTAMP NULL AFTER download_count;
