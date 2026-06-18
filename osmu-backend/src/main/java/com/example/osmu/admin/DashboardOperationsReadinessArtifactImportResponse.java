package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessArtifactImportResponse(
        String result,
        String status,
        int selectedGroupCount,
        int importedCount,
        int failedCount,
        String outputDirectory,
        String secretPolicy,
        List<DashboardOperationsReadinessArtifactImportEntryResponse> entries
) {
    public static DashboardOperationsReadinessArtifactImportResponse empty() {
        return new DashboardOperationsReadinessArtifactImportResponse("", "", 0, 0, 0, "", "", List.of());
    }
}
