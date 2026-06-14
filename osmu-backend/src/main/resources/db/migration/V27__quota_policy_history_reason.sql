ALTER TABLE quota_policy_history
    ADD COLUMN reason VARCHAR(512) NULL AFTER actor_id;
