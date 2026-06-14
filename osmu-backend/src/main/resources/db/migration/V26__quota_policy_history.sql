CREATE TABLE IF NOT EXISTS quota_policy_history (
    id BIGINT NOT NULL PRIMARY KEY,
    target_type VARCHAR(32) NOT NULL,
    target_id BIGINT NOT NULL,
    action VARCHAR(32) NOT NULL,
    previous_quota_bytes BIGINT NULL,
    new_quota_bytes BIGINT NULL,
    actor_id VARCHAR(128) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    KEY idx_quota_policy_history_target (target_type, target_id, id),
    KEY idx_quota_policy_history_created_at (created_at)
);
