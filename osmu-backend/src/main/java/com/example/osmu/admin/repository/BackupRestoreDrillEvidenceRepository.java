package com.example.osmu.admin.repository;

import com.example.osmu.admin.BackupRestoreDrillEvidenceResponse;
import java.util.List;
import java.util.Optional;

public interface BackupRestoreDrillEvidenceRepository {

    Optional<BackupRestoreDrillEvidenceResponse> findLatest();

    Optional<BackupRestoreDrillEvidenceResponse> findLatestByResult(String result);

    List<BackupRestoreDrillEvidenceResponse> findRecent(String result, int limit);

    BackupRestoreDrillEvidenceResponse save(BackupRestoreDrillEvidenceResponse evidence);

    boolean isHealthy();
}
