package com.example.osmu.storageexpansion.repository;

import com.example.osmu.storageexpansion.StorageExpansionExecutionRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface StorageExpansionExecutionRepository {

    List<StorageExpansionExecutionRecord> findAll();

    long countAll();

    long countByResult(String result);

    long countTimedOut();

    Optional<StorageExpansionExecutionRecord> findLatest();

    List<StorageExpansionExecutionRecord> findRecent(int limit);

    List<StorageExpansionExecutionRecord> findByRequestId(long requestId);

    Optional<StorageExpansionExecutionRecord> findById(long id);

    long nextId();

    StorageExpansionExecutionRecord save(StorageExpansionExecutionRecord execution);

    long countOutputsBefore(OffsetDateTime cutoff);

    int redactOutputsBefore(OffsetDateTime cutoff, int batchSize, String redactedOutput);

    boolean isHealthy();
}
