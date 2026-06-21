package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsHandoffPackageConvergenceSnapshotResponse(
        boolean provided,
        boolean parsed,
        String result,
        boolean ready,
        String readinessResult,
        String readinessSummary,
        boolean kubernetesReportSyncReady,
        String kubernetesReportSyncResult,
        int kubernetesReportSyncFailedCount,
        int stageCount,
        int readyStageCount,
        int finalizerGapCount,
        String currentBottleneckCode,
        String currentBottleneckTitle,
        int recommendedCommandCount
) {
}
