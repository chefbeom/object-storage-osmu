package com.example.osmu.admin;

import java.util.List;

public record BackupRestoreDrillEvidenceResponse(
        long auditLogId,
        String environment,
        String operator,
        String result,
        String startedAt,
        String completedAt,
        String backupTimestamp,
        long restoreDurationMinutes,
        long observedRpoHours,
        boolean rpoTargetMet,
        boolean rtoTargetMet,
        long metadataRowCount,
        long objectCount,
        long objectBytes,
        String backupManifestSha256,
        String evidenceUri,
        List<String> gaps,
        String statusImpact,
        String recordedAt
) {
}
