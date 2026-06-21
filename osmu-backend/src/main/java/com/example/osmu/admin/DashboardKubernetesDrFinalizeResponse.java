package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardKubernetesDrFinalizeResponse(
        String result,
        String status,
        String generatedAt,
        String startedAt,
        String completedAt,
        String sourceNamespace,
        String restoreNamespace,
        String backupTimestamp,
        boolean serverDryRunOnly,
        boolean confirmRestore,
        boolean runBackupDrill,
        boolean runRestoreSmoke,
        boolean writeEvidenceRequest,
        boolean submitEvidence,
        boolean runS3ClientSmoke,
        int failedStepCount,
        List<String> gaps,
        List<DashboardOperationsGateCommandResponse> commands,
        List<DashboardOperationsGateStepResponse> steps,
        String secretPolicy
) {
    public static DashboardKubernetesDrFinalizeResponse empty() {
        return new DashboardKubernetesDrFinalizeResponse(
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
                false,
                false,
                false,
                false,
                false,
                0,
                List.of(),
                List.of(),
                List.of(),
                ""
        );
    }
}
