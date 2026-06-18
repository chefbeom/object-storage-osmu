ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS previous_secret_key_hash VARCHAR(128) NULL;

ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS previous_secret_key_ciphertext TEXT NULL;

ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS previous_secret_key_expires_at TIMESTAMP NULL;
