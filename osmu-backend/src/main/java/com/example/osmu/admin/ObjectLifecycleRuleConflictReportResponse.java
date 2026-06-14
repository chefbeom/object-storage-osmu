package com.example.osmu.admin;

import java.util.List;

public record ObjectLifecycleRuleConflictReportResponse(
        int ruleCount,
        int conflictCount,
        List<ObjectLifecycleRuleConflictResponse> conflicts
) {
}
