CREATE INDEX IF NOT EXISTS idx_teams_organization_cursor
    ON teams (organization_id, id);
