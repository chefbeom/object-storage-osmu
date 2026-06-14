CREATE TABLE IF NOT EXISTS organizations (
    id BIGINT NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    default_quota_bytes BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS organization_id BIGINT NULL;

CREATE INDEX IF NOT EXISTS idx_users_organization_id ON users (organization_id);
