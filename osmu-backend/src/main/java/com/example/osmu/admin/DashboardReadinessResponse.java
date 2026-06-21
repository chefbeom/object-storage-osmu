package com.example.osmu.admin;

import java.time.OffsetDateTime;
import java.util.List;

public record DashboardReadinessResponse(
        String status,
        String runtimeProfile,
        int blockerCount,
        int warningCount,
        List<String> blockers,
        List<String> warnings,
        List<DashboardReadinessSeverityResponse> severitySummaries,
        List<DashboardReadinessCategoryResponse> categorySummaries,
        List<DashboardReadinessItemResponse> items,
        DashboardOperationsEvidencePlanResponse operationsEvidencePlan,
        DashboardOperationsEvidenceInvocationResponse operationsEvidenceInvocation,
        DashboardOperationsInvocationUnblockPlanResponse operationsInvocationUnblockPlan,
        DashboardOperationsDispatchPreflightResponse operationsDispatchPreflight,
        DashboardOperationsWorkflowRunIdPlanResponse operationsWorkflowRunIdPlan,
        DashboardOperationsArtifactCollectionPlanResponse operationsArtifactCollectionPlan,
        DashboardOperationsReadinessArtifactImportResponse operationsReadinessArtifactImport,
        DashboardOperationsReadinessFinalizeResponse operationsReadinessFinalize,
        DashboardOperationsHandoffPackageResponse operationsHandoffPackage,
        DashboardSecurityEvidenceResponse securityEvidence,
        DashboardSecretRotationEvidenceResponse secretRotationEvidence,
        DashboardCommercialIntegrationEvidenceResponse commercialIntegrationEvidence,
        DashboardCommercialApprovalEvidenceResponse commercialApprovalEvidence,
        DashboardEnterpriseAuthSmokeEvidenceResponse enterpriseAuthSmokeEvidence,
        DashboardDataFlowStoragePlanResponse dataFlowStoragePlan,
        DashboardStorageBackendTelemetryEvidenceResponse storageBackendTelemetryEvidence,
        DashboardOperationsEvidenceHandoffResponse operationsEvidenceHandoff,
        DashboardOperationsReadinessConvergenceResponse operationsReadinessConvergence,
        DashboardKubernetesOperationsReportSyncResponse kubernetesOperationsReportSync,
        OffsetDateTime generatedAt
) {
}
