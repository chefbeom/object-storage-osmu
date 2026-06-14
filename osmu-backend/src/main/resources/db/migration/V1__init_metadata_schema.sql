CREATE TABLE IF NOT EXISTS users (
    id BIGINT NOT NULL PRIMARY KEY,
    login_id VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id BIGINT NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    status VARCHAR(32) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP NULL,
    INDEX idx_refresh_tokens_user_id (user_id),
    INDEX idx_refresh_tokens_status (status),
    INDEX idx_refresh_tokens_expires_at (expires_at)
);

CREATE TABLE IF NOT EXISTS buckets (
    id BIGINT NOT NULL PRIMARY KEY,
    name VARCHAR(63) NOT NULL UNIQUE,
    owner_type VARCHAR(20) NOT NULL,
    owner_id BIGINT NOT NULL,
    quota_bytes BIGINT NOT NULL,
    used_bytes BIGINT NOT NULL,
    object_count BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    INDEX idx_buckets_owner (owner_type, owner_id)
);

CREATE TABLE IF NOT EXISTS access_keys (
    id BIGINT NOT NULL PRIMARY KEY,
    owner_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    access_key VARCHAR(128) NOT NULL UNIQUE,
    secret_key_hash VARCHAR(128) NOT NULL,
    allowed_buckets TEXT NOT NULL,
    permissions TEXT NOT NULL,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NULL,
    INDEX idx_access_keys_owner_id (owner_id),
    INDEX idx_access_keys_status (status)
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT NOT NULL PRIMARY KEY,
    event_type VARCHAR(80) NOT NULL,
    actor_id VARCHAR(120) NOT NULL,
    target_type VARCHAR(80) NOT NULL,
    target_id VARCHAR(255) NOT NULL,
    result VARCHAR(40) NOT NULL,
    message VARCHAR(500) NOT NULL,
    ip_address VARCHAR(80),
    user_agent VARCHAR(500),
    request_id VARCHAR(120),
    created_at TIMESTAMP NOT NULL,
    INDEX idx_audit_logs_created_at (created_at),
    INDEX idx_audit_logs_event_type (event_type),
    INDEX idx_audit_logs_actor_id (actor_id)
);
