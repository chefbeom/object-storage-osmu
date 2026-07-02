package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardSupportEscalationHandoffEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        Map<String, String> reviewWindow,
        Map<String, String> evidence,
        Map<String, Boolean> documentSnapshot,
        Map<String, Boolean> confirmations,
        int passCount,
        int failureCount,
        int totalCount,
        List<DashboardSupportEscalationHandoffCheckResponse> checks,
        String scopePolicy,
        String secretPolicy,
        String decisionRule
) {
    public static DashboardSupportEscalationHandoffEvidenceResponse empty() {
        return new DashboardSupportEscalationHandoffEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                Map.of(),
                Map.of(),
                Map.of(),
                Map.of(),
                0,
                0,
                0,
                List.of(),
                "",
                "",
                ""
        );
    }
}
