package com.example.osmu.admin.repository;

import com.example.osmu.admin.BackupRestoreDrillEvidenceResponse;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryBackupRestoreDrillEvidenceRepository implements BackupRestoreDrillEvidenceRepository {

    private final ConcurrentMap<Long, BackupRestoreDrillEvidenceResponse> evidenceByAuditLogId = new ConcurrentHashMap<>();

    @Override
    public Optional<BackupRestoreDrillEvidenceResponse> findLatest() {
        return evidenceByAuditLogId.values().stream()
                .max(Comparator.comparingLong(BackupRestoreDrillEvidenceResponse::auditLogId));
    }

    @Override
    public Optional<BackupRestoreDrillEvidenceResponse> findLatestByResult(String result) {
        String normalizedResult = normalizeResult(result);
        if (normalizedResult == null) {
            return findLatest();
        }
        return evidenceByAuditLogId.values().stream()
                .filter(evidence -> normalizedResult.equals(evidence.result()))
                .max(Comparator.comparingLong(BackupRestoreDrillEvidenceResponse::auditLogId));
    }

    @Override
    public List<BackupRestoreDrillEvidenceResponse> findRecent(String result, int limit) {
        String normalizedResult = normalizeResult(result);
        return evidenceByAuditLogId.values().stream()
                .filter(evidence -> normalizedResult == null || normalizedResult.equals(evidence.result()))
                .sorted(Comparator.comparingLong(BackupRestoreDrillEvidenceResponse::auditLogId).reversed())
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public BackupRestoreDrillEvidenceResponse save(BackupRestoreDrillEvidenceResponse evidence) {
        evidenceByAuditLogId.put(evidence.auditLogId(), evidence);
        return evidence;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private String normalizeResult(String result) {
        return result == null || result.isBlank() ? null : result.trim().toUpperCase(java.util.Locale.ROOT);
    }
}
