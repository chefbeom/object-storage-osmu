CREATE INDEX IF NOT EXISTS idx_users_organization_cursor
    ON users (organization_id, id);

CREATE INDEX IF NOT EXISTS idx_users_status_cursor
    ON users (status, id);