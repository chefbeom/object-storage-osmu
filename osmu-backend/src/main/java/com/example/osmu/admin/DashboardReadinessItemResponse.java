package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardReadinessItemResponse(
        String severity,
        String category,
        String code,
        String message,
        String targetPage,
        String targetPanel,
        String actionLabel,
        String evidencePath,
        String remediationCommand,
        String remediationWorkflow,
        String remediationWorkflowCommand,
        String remediationNote
) {
    public DashboardReadinessItemResponse(
            String severity,
            String category,
            String code,
            String message,
            String targetPage,
            String targetPanel,
            String actionLabel
    ) {
        this(severity, category, code, message, targetPage, targetPanel, actionLabel, "", "", "", "", "");
    }
}
