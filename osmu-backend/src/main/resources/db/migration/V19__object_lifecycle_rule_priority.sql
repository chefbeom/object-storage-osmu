ALTER TABLE object_lifecycle_rules
  ADD COLUMN priority INT NOT NULL DEFAULT 100 AFTER enabled;

CREATE INDEX idx_object_lifecycle_rules_priority
  ON object_lifecycle_rules (priority, created_at, rule_id);
