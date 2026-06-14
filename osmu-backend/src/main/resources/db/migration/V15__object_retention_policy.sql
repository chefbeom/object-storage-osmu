CREATE TABLE IF NOT EXISTS object_retention_policy (
  id TINYINT NOT NULL PRIMARY KEY,
  enabled BOOLEAN NOT NULL,
  retention_days INT NOT NULL,
  batch_size INT NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT chk_object_retention_policy_singleton CHECK (id = 1),
  CONSTRAINT chk_object_retention_policy_days CHECK (retention_days >= 1),
  CONSTRAINT chk_object_retention_policy_batch CHECK (batch_size >= 1)
);

INSERT INTO object_retention_policy (id, enabled, retention_days, batch_size, updated_at)
VALUES (1, TRUE, 30, 100, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE id = id;
