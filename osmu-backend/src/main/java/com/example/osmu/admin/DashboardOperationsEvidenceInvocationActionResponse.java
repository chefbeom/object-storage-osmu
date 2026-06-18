package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceInvocationActionResponse(
        int order,
        String name,
        String category,
        String actionType,
        String evidencePath,
        String commandMode,
        String command,
        String status,
        List<String> blockReasons,
        List<String> unresolvedPlaceholders,
        boolean requiresOperatorApproval,
        boolean requiresKubeconfigSecret,
        Integer exitCode
) {
}
