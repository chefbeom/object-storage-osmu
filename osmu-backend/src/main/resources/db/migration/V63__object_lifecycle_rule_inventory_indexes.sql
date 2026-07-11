CREATE INDEX IF NOT EXISTS idx_object_lifecycle_rules_inventory_order
    ON object_lifecycle_rules (priority, created_at, rule_id);

CREATE INDEX IF NOT EXISTS idx_object_lifecycle_rules_enabled_order
    ON object_lifecycle_rules (enabled, priority, created_at, rule_id);

CREATE INDEX IF NOT EXISTS idx_object_lifecycle_rules_target_inventory_order
    ON object_lifecycle_rules (target_type, priority, created_at, rule_id);
