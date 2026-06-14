ALTER TABLE object_share_links
    ADD COLUMN IF NOT EXISTS allowed_ip_cidrs VARCHAR(512) NULL AFTER password_hash;
