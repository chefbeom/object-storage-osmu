package com.example.osmu.admin;

import java.util.List;

public record BackupRestoreDrillEvidenceRequest(
        String environment,
        String operator,
        String result,
        String startedAt,
        String completedAt,
        String backupTimestamp,
        Long metadataRowCount,
        Long objectCount,
        Long objectBytes,
        String backupManifestSha256,
        String evidenceUri,
        List<String> gaps
) {
}
