package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardHardeningEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        Map<String, String> reviewWindow,
        Map<String, String> evidence,
        Map<String, String> staticSnapshot,
        Map<String, Boolean> confirmations,
        int passCount,
        int failureCount,
        int totalCount,
        List<DashboardHardeningEvidenceCheckResponse> checks,
        String scopePolicy,
        String secretPolicy,
        String decisionRule
) {
    public static DashboardHardeningEvidenceResponse empty() {
        return new DashboardHardeningEvidenceResponse(
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
