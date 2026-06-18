CREATE INDEX IF NOT EXISTS idx_storage_expansion_summary
    ON storage_expansion_requests (status, requested_capacity_bytes, estimated_usable_capacity_bytes, id);
