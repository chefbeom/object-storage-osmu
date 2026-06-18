package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessArtifactImportEntryResponse(
        String group,
        String fileName,
        String status,
        boolean passed,
        String detail,
        String sourcePath,
        String destinationPath
) {
}
