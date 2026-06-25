package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffResponse(
        String result,
        String generatedAt,
        DashboardOperationsEvidenceHandoffNextStepResponse nextStep,
        int stageCount,
        int readyStageCount,
        String dispatchPreflightResult,
        int readyDispatchTemplateCount,
        int blockedDispatchTemplateCount,
        List<Integer> readyDispatchActionOrders,
        List<Integer> blockedDispatchActionOrders,
        List<DashboardOperationsEvidenceHandoffDispatchWorkflowResponse> readyDispatchWorkflows,
        List<DashboardOperationsEvidenceHandoffDispatchWorkflowResponse> blockedDispatchWorkflows,
        int blockedActionCount,
        int missingWorkflowRunCount,
        int missingRequiredArtifactCount,
        int failedImportCount,
        int finalizerFailedCount,
        int finalizerGapCount,
        List<DashboardOperationsEvidenceHandoffStageResponse> stages
) {
    public static DashboardOperationsEvidenceHandoffResponse empty() {
        return new DashboardOperationsEvidenceHandoffResponse(
                "",
                "",
                DashboardOperationsEvidenceHandoffNextStepResponse.empty(),
                0,
                0,
                "",
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                0,
                0,
                0,
                0,
                0,
                0,
                List.of()
        );
    }
}
