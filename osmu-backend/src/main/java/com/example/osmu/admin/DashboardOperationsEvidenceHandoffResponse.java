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
