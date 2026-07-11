CREATE TABLE IF NOT EXISTS storage_layout_plans (
    id BIGINT NOT NULL PRIMARY KEY,
    layout_code VARCHAR(32) NOT NULL,
    storage_class_name VARCHAR(128) NOT NULL,
    server_count INT NOT NULL,
    volumes_per_server INT NOT NULL,
    volume_size_gib BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL,
    reason VARCHAR(512) NULL,
    created_by VARCHAR(128) NOT NULL,
    approved_by VARCHAR(128) NULL,
    approved_at TIMESTAMP NULL,
    simulated_by VARCHAR(128) NULL,
    simulated_at TIMESTAMP NULL,
    admin_note VARCHAR(512) NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    INDEX idx_storage_layout_plans_status (status, id)
);
