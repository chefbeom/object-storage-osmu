package com.example.osmu.admin;

public record UpdateObjectRetentionPolicyRequest(
        Boolean enabled,
        Integer retentionDays,
        Integer batchSize,
        Integer versionRetentionDays,
        Integer versionBatchSize
) {
}
