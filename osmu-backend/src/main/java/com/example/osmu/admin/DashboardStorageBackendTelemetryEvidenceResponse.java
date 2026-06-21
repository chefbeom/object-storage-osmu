package com.example.osmu.admin;

public record DashboardStorageBackendTelemetryEvidenceResponse(
        String result,
        String generatedAt,
        String environmentName,
        String targetCluster,
        String operatorName,
        String sourceMode,
        String minioAlias,
        String evidenceRef,
        String adminInfoJsonSha256,
        boolean rawAdminInfoStored,
        int poolCount,
        int serverCount,
        int onlineServerCount,
        int offlineServerCount,
        int driveCount,
        long totalBytes,
        long usedBytes,
        long freeBytes,
        boolean capacityKnown,
        int failureCount,
        int plannedCount,
        String decisionRule,
        String scopePolicy
) {
    public static DashboardStorageBackendTelemetryEvidenceResponse empty() {
        return new DashboardStorageBackendTelemetryEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                false,
                0,
                0,
                0,
                0,
                0,
                0L,
                0L,
                0L,
                false,
                0,
                0,
                "",
                ""
        );
    }
}
