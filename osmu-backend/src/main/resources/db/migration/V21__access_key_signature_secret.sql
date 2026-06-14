ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS secret_key_ciphertext TEXT NULL;
