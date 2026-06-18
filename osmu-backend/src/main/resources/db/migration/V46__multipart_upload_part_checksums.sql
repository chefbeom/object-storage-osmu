CREATE TABLE IF NOT EXISTS multipart_upload_part_checksums (
    upload_id VARCHAR(64) NOT NULL,
    part_number INT NOT NULL,
    checksums TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (upload_id, part_number),
    INDEX idx_multipart_upload_part_checksums_upload_id (upload_id)
);
