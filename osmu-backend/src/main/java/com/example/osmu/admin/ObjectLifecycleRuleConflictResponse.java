package com.example.osmu.admin;

import com.example.osmu.object.ObjectLifecycleRule;

public record ObjectLifecycleRuleConflictResponse(
        String conflictType,
        String severity,
        String targetType,
        ObjectLifecycleRule firstRule,
        ObjectLifecycleRule secondRule,
        String reason
) {
}
