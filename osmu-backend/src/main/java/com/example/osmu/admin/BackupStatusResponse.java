package com.example.osmu.admin;

import java.util.List;

public record BackupStatusResponse(
        String status,
        String metadataStore,
        String objectStore,
        boolean databaseHealthy,
        boolean storageHealthy,
        String rpoTarget,
        String rtoTarget,
        boolean runbookAvailable,
        boolean restoreDrillExecuted,
        String lastBackupAt,
        String lastRestoreDrillAt,
        BackupRestoreDrillEvidenceResponse latestRestoreDrillEvidence,
        List<String> pendingGates
) {
}
