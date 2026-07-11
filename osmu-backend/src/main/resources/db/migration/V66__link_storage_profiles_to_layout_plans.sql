ALTER TABLE bucket_storage_profile_assignments
    ADD COLUMN storage_layout_plan_id BIGINT NULL AFTER profile_code,
    ADD COLUMN storage_pool_name VARCHAR(128) NULL AFTER storage_layout_plan_id,
    ADD COLUMN storage_layout_code VARCHAR(32) NULL AFTER storage_pool_name;

ALTER TABLE storage_profile_requests
    ADD COLUMN storage_layout_plan_id BIGINT NULL AFTER applied_at,
    ADD COLUMN storage_pool_name VARCHAR(128) NULL AFTER storage_layout_plan_id,
    ADD COLUMN storage_layout_code VARCHAR(32) NULL AFTER storage_pool_name;
