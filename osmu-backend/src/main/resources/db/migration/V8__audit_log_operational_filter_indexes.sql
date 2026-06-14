CREATE INDEX IF NOT EXISTS idx_audit_logs_target_type ON audit_logs (target_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target_id ON audit_logs (target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_result ON audit_logs (result);
