package com.example.osmu.admin;

public record DashboardHardeningEvidenceCheckResponse(
        String id,
        String name,
        String status,
        boolean passed,
        String detail,
        String evidenceRef
) {
}
