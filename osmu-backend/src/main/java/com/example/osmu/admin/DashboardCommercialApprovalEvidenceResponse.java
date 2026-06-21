package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardCommercialApprovalEvidenceResponse(
        String result,
        String generatedAt,
        String productVersion,
        String approvedBy,
        String approvedAt,
        int passedCount,
        int failureCount,
        int checkCount,
        boolean pricingPolicyProposalCommercialApproved,
        int pricingPolicyProposalCommercialApprovedCount,
        int pricingPolicyProposalApprovedPriceListCount,
        Map<String, Boolean> confirmations,
        Map<String, String> evidenceRefs,
        List<DashboardCommercialEvidenceCheckResponse> checks,
        String decisionRule,
        String scopePolicy,
        String secretPolicy
) {
    public static DashboardCommercialApprovalEvidenceResponse empty() {
        return new DashboardCommercialApprovalEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                false,
                0,
                0,
                Map.of(),
                Map.of(),
                List.of(),
                "",
                "",
                ""
        );
    }
}
