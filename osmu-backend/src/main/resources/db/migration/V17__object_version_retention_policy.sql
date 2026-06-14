ALTER TABLE object_retention_policy
  ADD COLUMN IF NOT EXISTS version_retention_days INT NOT NULL DEFAULT 90,
  ADD COLUMN IF NOT EXISTS version_batch_size INT NOT NULL DEFAULT 100;
