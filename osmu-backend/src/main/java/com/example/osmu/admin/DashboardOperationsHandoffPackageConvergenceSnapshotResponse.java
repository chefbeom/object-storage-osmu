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
        String finalizerResult,
        String finalizerReadinessResult,
        int finalizerFailedCount,
        boolean finalizerFailedCountValid,
        String finalizerFailedCountRaw,
        boolean finalizerGapCountValid,
        String finalizerGapCountRaw,
        boolean kubernetesReportSyncReady,
        boolean kubernetesReportSyncReadyValid,
        String kubernetesReportSyncReadyRaw,
        String kubernetesReportSyncResult,
        int kubernetesReportSyncFailedCount,
        boolean kubernetesReportSyncFailedCountValid,
        String kubernetesReportSyncFailedCountRaw,
        String kubernetesReportSyncSourceReportResult,
        int stageCount,
        int readyStageCount,
        int finalizerGapCount,
        String currentBottleneckCode,
        String currentBottleneckTitle,
        int recommendedCommandCount
) {
}
