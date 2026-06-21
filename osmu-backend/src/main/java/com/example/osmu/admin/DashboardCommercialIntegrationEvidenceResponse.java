package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardCommercialIntegrationEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        int integrationCount,
        int verifiedCount,
        int requiredCount,
        int requiredVerifiedCount,
        boolean paymentProviderAdapterReadinessReviewed,
        String paymentProviderAdapterReadinessStatus,
        int paymentProviderAdapterWebhookReadyProfileCount,
        int paymentProviderAdapterNativeReadyProfileCount,
        int failureCount,
        int plannedCount,
        List<DashboardCommercialEvidenceCheckResponse> checks,
        String decisionRule,
        String scopePolicy,
        String secretPolicy
) {
    public static DashboardCommercialIntegrationEvidenceResponse empty() {
        return new DashboardCommercialIntegrationEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                false,
                "",
                0,
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
