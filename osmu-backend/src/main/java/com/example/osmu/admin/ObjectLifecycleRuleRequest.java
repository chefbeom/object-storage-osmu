package com.example.osmu.admin;

public record ObjectLifecycleRuleRequest(
        String ruleId,
        String name,
        Boolean enabled,
        Integer priority,
        String bucketName,
        String targetType,
        String prefix,
        String tags,
        Integer retentionDays,
        Integer batchSize
) {
}
