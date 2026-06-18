CREATE INDEX IF NOT EXISTS idx_storage_expansion_execution_result
    ON storage_expansion_executions (result, id);

CREATE INDEX IF NOT EXISTS idx_storage_expansion_execution_timeout
    ON storage_expansion_executions (timed_out, id);
