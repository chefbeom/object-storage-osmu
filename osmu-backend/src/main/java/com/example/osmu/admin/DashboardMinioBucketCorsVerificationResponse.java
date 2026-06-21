package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardMinioBucketCorsVerificationResponse(
        String result,
        String generatedAt,
        String sourceMode,
        String bucketName,
        String minioAlias,
        String sourceRef,
        boolean executeRequested,
        boolean rawCorsXmlStored,
        int ruleCount,
        int exposedHeaderCount,
        int failureCount,
        int plannedCount,
        List<String> allowedOrigins,
        List<String> allowedMethods,
        List<String> allowedHeaders,
        List<String> exposeHeaders,
        List<Integer> maxAgeSeconds,
        List<DashboardMinioBucketCorsCheckResponse> checks,
        String decisionRule,
        String scopePolicy,
        DashboardMinioBucketCorsCommandsResponse operatorCommands
) {
    public static DashboardMinioBucketCorsVerificationResponse empty() {
        return new DashboardMinioBucketCorsVerificationResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                false,
                false,
                0,
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                "",
                "",
                DashboardMinioBucketCorsCommandsResponse.empty()
        );
    }
}
