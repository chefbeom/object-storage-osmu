CREATE TABLE IF NOT EXISTS object_share_policy (
    id TINYINT NOT NULL PRIMARY KEY,
    require_password BOOLEAN NOT NULL DEFAULT FALSE,
    require_ip_allowlist BOOLEAN NOT NULL DEFAULT FALSE,
    max_expires_seconds INT NOT NULL DEFAULT 604800,
    max_downloads_limit INT NULL,
    updated_at TIMESTAMP NULL
);
