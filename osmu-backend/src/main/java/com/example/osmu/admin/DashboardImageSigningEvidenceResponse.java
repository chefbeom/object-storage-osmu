package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardImageSigningEvidenceResponse(
        String result,
        String generatedAt,
        int failureCount,
        String version,
        String commitSha,
        String sourceRunUrl,
        String issuer,
        String signingMode,
        String backendVersionRef,
        String backendShaRef,
        String backendDigest,
        boolean backendVersionSignatureVerified,
        boolean backendShaSignatureVerified,
        String frontendVersionRef,
        String frontendShaRef,
        String frontendDigest,
        boolean frontendVersionSignatureVerified,
        boolean frontendShaSignatureVerified,
        String secretPolicy
) {
    public static DashboardImageSigningEvidenceResponse empty() {
        return new DashboardImageSigningEvidenceResponse(
                "",
                "",
                0,
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
                false,
                false,
                ""
        );
    }
}
