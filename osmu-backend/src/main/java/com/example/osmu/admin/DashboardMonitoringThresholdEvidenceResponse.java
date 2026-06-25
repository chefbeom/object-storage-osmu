package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardMonitoringThresholdEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        String evidenceRef,
        Map<String, String> reviewWindow,
        String thresholdTargetsPath,
        int requiredAlertCount,
        int mappedAlertCount,
        List<String> missingAlerts,
        int routeCount,
        List<String> routes,
        int grafanaPanelCount,
        int tuningEvidenceCount,
        boolean alertTargetCoverageComplete,
        boolean routeCoverageComplete,
        boolean grafanaPanelCoverageComplete,
        boolean tuningEvidenceCoverageComplete,
        boolean thresholdMappingComplete,
        Map<String, String> evidenceRefs,
        Map<String, Boolean> confirmations,
        int failureCount,
        int checkCount,
        List<DashboardMonitoringThresholdCheckResponse> checks,
        String decisionRule,
        String secretPolicy
) {
    public static DashboardMonitoringThresholdEvidenceResponse empty() {
        return new DashboardMonitoringThresholdEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                Map.of(),
                "",
                0,
                0,
                List.of(),
                0,
                List.of(),
                0,
                0,
                false,
                false,
                false,
                false,
                false,
                Map.of(),
                Map.of(),
                0,
                0,
                List.of(),
                "",
                ""
        );
    }
}
