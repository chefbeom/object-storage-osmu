ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS allowed_buckets TEXT NULL;
ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS permissions TEXT NULL;

UPDATE access_keys
SET allowed_buckets = '["*"]'
WHERE allowed_buckets IS NULL;

UPDATE access_keys
SET permissions = '["READ","WRITE","DELETE"]'
WHERE permissions IS NULL;

ALTER TABLE access_keys MODIFY COLUMN allowed_buckets TEXT NOT NULL;
ALTER TABLE access_keys MODIFY COLUMN permissions TEXT NOT NULL;
