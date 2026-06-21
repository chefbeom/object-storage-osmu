package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardSecretRotationEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        Map<String, String> rotationWindow,
        Map<String, String> evidenceRefs,
        Map<String, Boolean> confirmations,
        int rotatedCount,
        int coreRotatedCount,
        int coreRequiredCount,
        int failureCount,
        int plannedCount,
        List<DashboardSecretRotationItemResponse> rotations,
        List<DashboardSecretRotationCheckResponse> checks,
        String decisionRule,
        String secretPolicy
) {
    public static DashboardSecretRotationEvidenceResponse empty() {
        return new DashboardSecretRotationEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                Map.of(),
                Map.of(),
                Map.of(),
                0,
                0,
                0,
                0,
                0,
                List.of(),
                List.of(),
                "",
                ""
        );
    }
}
