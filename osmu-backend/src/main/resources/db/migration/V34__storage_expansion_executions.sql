CREATE TABLE IF NOT EXISTS storage_expansion_executions (
    id BIGINT NOT NULL PRIMARY KEY,
    request_id BIGINT NOT NULL,
    execution_type VARCHAR(32) NOT NULL,
    result VARCHAR(32) NOT NULL,
    command_text VARCHAR(1024) NULL,
    output_text MEDIUMTEXT NULL,
    external_url VARCHAR(1024) NULL,
    artifact_sha256 VARCHAR(128) NULL,
    notes VARCHAR(1024) NULL,
    created_by VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    KEY idx_storage_expansion_execution_request (request_id, id),
    KEY idx_storage_expansion_execution_type (execution_type, result)
);
