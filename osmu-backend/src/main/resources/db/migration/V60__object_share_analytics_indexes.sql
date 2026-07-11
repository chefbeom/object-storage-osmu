CREATE INDEX IF NOT EXISTS idx_object_share_links_bucket_id
    ON object_share_links (bucket_name, id);

CREATE INDEX IF NOT EXISTS idx_object_share_links_status_id
    ON object_share_links (status, id);

CREATE INDEX IF NOT EXISTS idx_object_share_links_bucket_status_id
    ON object_share_links (bucket_name, status, id);