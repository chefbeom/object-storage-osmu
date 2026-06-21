package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardContainerSecurityEvidenceResponse(
        String result,
        String generatedAt,
        int failureCount,
        String backendImage,
        String frontendImage,
        String commitSha,
        String sourceRunUrl,
        String artifactName,
        String severity,
        boolean ignoreUnfixed,
        boolean backendScanPassed,
        boolean frontendScanPassed,
        boolean backendSbomValid,
        int backendSbomPackageCount,
        long backendSbomByteSize,
        String backendSbomSha256,
        boolean frontendSbomValid,
        int frontendSbomPackageCount,
        long frontendSbomByteSize,
        String frontendSbomSha256,
        String secretPolicy
) {
    public static DashboardContainerSecurityEvidenceResponse empty() {
        return new DashboardContainerSecurityEvidenceResponse(
                "",
                "",
                0,
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
                0,
                0L,
                "",
                false,
                0,
                0L,
                "",
                ""
        );
    }
}
