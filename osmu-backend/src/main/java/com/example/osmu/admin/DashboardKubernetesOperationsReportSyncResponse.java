package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardKubernetesOperationsReportSyncResponse(
        String result,
        String generatedAt,
        String namespace,
        String configMapName,
        String configMapKey,
        String evidenceConfigMapKey,
        String dataFlowStoragePlanConfigMapKey,
        String dataFlowStorageTransitionRunbookConfigMapKey,
        boolean publishDataFlowStoragePlanToConfigMap,
        boolean publishDataFlowStorageTransitionRunbookToConfigMap,
        String sourceReportPath,
        String sourceReportFormatVersion,
        String sourceReportResult,
        long sourceReportBytes,
        String sourceReportSha256,
        String dataFlowStorageTransitionRunbookResult,
        String dataFlowStorageTransitionRunbookStoragePlanResult,
        String dataFlowStorageTransitionRunbookCandidateStore,
        int dataFlowStorageTransitionRunbookFailureCount,
        int dataFlowStorageTransitionRunbookCheckCount,
        long dataFlowStorageTransitionRunbookBytes,
        String dataFlowStorageTransitionRunbookSha256,
        String clientDryRunCommand,
        String serverDryRunCommand,
        String applyCommand,
        int checkCount,
        int failedCount,
        List<DashboardKubernetesOperationsReportSyncCheckResponse> checks,
        String safetyPolicy
) {
    public static DashboardKubernetesOperationsReportSyncResponse empty() {
        return new DashboardKubernetesOperationsReportSyncResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                false,
                false,
                "",
                "",
                "",
                0L,
                "",
                "",
                "",
                "",
                0,
                0,
                0L,
                "",
                "",
                "",
                "",
                0,
                0,
                List.of(),
                ""
        );
    }
}
