package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardKubernetesHaDrReadinessResponse(
        String result,
        String generatedAt,
        String namespace,
        String kubectlPath,
        String restoreManifestPath,
        int failureCount,
        List<DashboardOperationsGateCheckResponse> checks
) {
    public static DashboardKubernetesHaDrReadinessResponse empty() {
        return new DashboardKubernetesHaDrReadinessResponse(
                "",
                "",
                "",
                "",
                "",
                0,
                List.of()
        );
    }
}
