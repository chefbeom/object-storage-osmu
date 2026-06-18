ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS usage_count BIGINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_access_keys_usage_count ON access_keys (usage_count);
