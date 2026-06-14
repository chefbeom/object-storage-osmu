ALTER TABLE object_lifecycle_rules
  ADD COLUMN bucket_name VARCHAR(63) NOT NULL DEFAULT '' AFTER priority;

CREATE INDEX idx_object_lifecycle_rules_bucket_target
  ON object_lifecycle_rules (bucket_name, enabled, target_type, priority);
