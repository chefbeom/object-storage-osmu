ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP NULL;

CREATE INDEX IF NOT EXISTS idx_access_keys_last_used_at ON access_keys (last_used_at);
