ALTER TABLE data_flow_daily_rollups
    ADD COLUMN actor_id VARCHAR(255) NOT NULL DEFAULT '' AFTER bucket_name,
    ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT '' AFTER operation;

ALTER TABLE data_flow_daily_rollups
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (rollup_day, bucket_name, actor_id, source, operation, status);

CREATE INDEX idx_data_flow_daily_rollups_actor
    ON data_flow_daily_rollups (actor_id, rollup_day);

CREATE INDEX idx_data_flow_daily_rollups_status
    ON data_flow_daily_rollups (status, rollup_day);
