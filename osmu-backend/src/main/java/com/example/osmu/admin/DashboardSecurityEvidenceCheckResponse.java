package com.example.osmu.admin;

public record DashboardSecurityEvidenceCheckResponse(
        String name,
        boolean passed,
        String detail,
        String evidencePath
) {
}
