package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardEnterpriseAuthJitRollbackEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        String evidenceRef,
        Map<String, String> reviewWindow,
        DashboardEnterpriseAuthJitRollbackSmokeSummaryResponse enterpriseAuthSmokeSnapshot,
        Map<String, String> evidenceRefs,
        Map<String, Boolean> confirmations,
        int failureCount,
        int checkCount,
        List<DashboardCommercialEvidenceCheckResponse> checks,
        String decisionRule,
        String scopePolicy,
        String secretPolicy
) {
    public static DashboardEnterpriseAuthJitRollbackEvidenceResponse empty() {
        return new DashboardEnterpriseAuthJitRollbackEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                Map.of(),
                DashboardEnterpriseAuthJitRollbackSmokeSummaryResponse.empty(),
                Map.of(),
                Map.of(),
                0,
                0,
                List.of(),
                "",
                "",
                ""
        );
    }
}
