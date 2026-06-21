package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardSecurityEvidenceResponse(
        String result,
        String generatedAt,
        int failureCount,
        boolean allowSyntheticEvidence,
        Map<String, String> inputs,
        Map<String, String> promoted,
        Map<String, String> source,
        Map<String, String> images,
        List<DashboardSecurityEvidenceCheckResponse> checks,
        DashboardImageSigningEvidenceResponse imageSigning,
        DashboardContainerSecurityEvidenceResponse containerSecurity,
        String decisionRule,
        String secretPolicy
) {
    public static DashboardSecurityEvidenceResponse empty() {
        return new DashboardSecurityEvidenceResponse(
                "",
                "",
                0,
                false,
                Map.of(),
                Map.of(),
                Map.of(),
                Map.of(),
                List.of(),
                DashboardImageSigningEvidenceResponse.empty(),
                DashboardContainerSecurityEvidenceResponse.empty(),
                "",
                ""
        );
    }
}
