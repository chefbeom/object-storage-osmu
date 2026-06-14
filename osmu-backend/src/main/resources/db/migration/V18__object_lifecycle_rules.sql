CREATE TABLE IF NOT EXISTS object_lifecycle_rules (
  rule_id VARCHAR(64) NOT NULL PRIMARY KEY,
  name VARCHAR(128) NOT NULL,
  enabled BOOLEAN NOT NULL,
  target_type VARCHAR(32) NOT NULL,
  prefix VARCHAR(1024) NOT NULL,
  tags TEXT NOT NULL,
  retention_days INT NOT NULL,
  batch_size INT NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  KEY idx_object_lifecycle_rules_target (enabled, target_type),
  CONSTRAINT chk_object_lifecycle_rules_retention_days CHECK (retention_days >= 1),
  CONSTRAINT chk_object_lifecycle_rules_batch_size CHECK (batch_size >= 1)
);
