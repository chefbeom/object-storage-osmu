CREATE TABLE IF NOT EXISTS data_flow_daily_rollups (
    rollup_day DATE NOT NULL,
    bucket_name VARCHAR(255) NOT NULL,
    source VARCHAR(64) NOT NULL,
    operation VARCHAR(64) NOT NULL,
    success_count BIGINT NOT NULL DEFAULT 0,
    failure_count BIGINT NOT NULL DEFAULT 0,
    cancel_count BIGINT NOT NULL DEFAULT 0,
    total_count BIGINT NOT NULL DEFAULT 0,
    uploaded_bytes BIGINT NOT NULL DEFAULT 0,
    downloaded_bytes BIGINT NOT NULL DEFAULT 0,
    copied_bytes BIGINT NOT NULL DEFAULT 0,
    total_bytes BIGINT NOT NULL DEFAULT 0,
    refreshed_at TIMESTAMP NOT NULL,
    PRIMARY KEY (rollup_day, bucket_name, source, operation),
    KEY idx_data_flow_daily_rollups_bucket (bucket_name, rollup_day),
    KEY idx_data_flow_daily_rollups_operation (operation, rollup_day),
    KEY idx_data_flow_daily_rollups_refreshed_at (refreshed_at)
);
