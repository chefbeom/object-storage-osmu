CREATE INDEX IF NOT EXISTS idx_object_lifecycle_rules_target_order
    ON object_lifecycle_rules (enabled, target_type, priority, created_at, rule_id);

CREATE INDEX IF NOT EXISTS idx_object_lifecycle_rules_bucket_order
    ON object_lifecycle_rules (bucket_name, priority, created_at, rule_id);