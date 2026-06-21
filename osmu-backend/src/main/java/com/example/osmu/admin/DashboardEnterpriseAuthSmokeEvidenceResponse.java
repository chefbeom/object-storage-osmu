package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardEnterpriseAuthSmokeEvidenceResponse(
        String result,
        String generatedAt,
        String executionMode,
        String apiBase,
        boolean requireOidc,
        boolean requireLdap,
        boolean requireAuditEvents,
        Map<String, Boolean> inputs,
        Map<String, String> scopeOut,
        int passCount,
        int failCount,
        int blockedCount,
        int plannedCount,
        int skippedCount,
        List<DashboardEnterpriseAuthSmokeCheckResponse> checks,
        String decisionRule,
        String secretPolicy
) {
    public static DashboardEnterpriseAuthSmokeEvidenceResponse empty() {
        return new DashboardEnterpriseAuthSmokeEvidenceResponse(
                "",
                "",
                "",
                "",
                false,
                false,
                false,
                Map.of(),
                Map.of(),
                0,
                0,
                0,
                0,
                0,
                List.of(),
                "",
                ""
        );
    }
}
