package com.example.osmu.storageexpansion.repository;

import com.example.osmu.storageexpansion.StorageExpansionExecutionRecord;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryStorageExpansionExecutionRepository implements StorageExpansionExecutionRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, StorageExpansionExecutionRecord> executions = new ConcurrentHashMap<>();

    @Override
    public List<StorageExpansionExecutionRecord> findAll() {
        return executions.values().stream()
                .sorted(Comparator.comparingLong(StorageExpansionExecutionRecord::id).reversed())
                .toList();
    }

    @Override
    public long countAll() {
        return executions.size();
    }

    @Override
    public long countByResult(String result) {
        return executions.values().stream()
                .filter(execution -> result.equals(execution.result()))
                .count();
    }

    @Override
    public long countTimedOut() {
        return executions.values().stream()
                .filter(StorageExpansionExecutionRecord::timedOut)
                .count();
    }

    @Override
    public Optional<StorageExpansionExecutionRecord> findLatest() {
        return executions.values().stream()
                .max(Comparator.comparingLong(StorageExpansionExecutionRecord::id));
    }

    @Override
    public List<StorageExpansionExecutionRecord> findRecent(int limit) {
        return executions.values().stream()
                .sorted(Comparator.comparingLong(StorageExpansionExecutionRecord::id).reversed())
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public List<StorageExpansionExecutionRecord> findByRequestId(long requestId) {
        return executions.values().stream()
                .filter(execution -> execution.requestId() == requestId)
                .sorted(Comparator.comparingLong(StorageExpansionExecutionRecord::id).reversed())
                .toList();
    }

    @Override
    public Optional<StorageExpansionExecutionRecord> findById(long id) {
        return Optional.ofNullable(executions.get(id));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public StorageExpansionExecutionRecord save(StorageExpansionExecutionRecord execution) {
        executions.put(execution.id(), execution);
        return execution;
    }

    @Override
    public long countOutputsBefore(OffsetDateTime cutoff) {
        return executions.values().stream()
                .filter(execution -> hasRetainedOutputBefore(execution, cutoff))
                .count();
    }

    @Override
    public int redactOutputsBefore(OffsetDateTime cutoff, int batchSize, String redactedOutput) {
        List<StorageExpansionExecutionRecord> candidates = executions.values().stream()
                .filter(execution -> hasRetainedOutputBefore(execution, cutoff))
                .sorted(Comparator.comparing(StorageExpansionExecutionRecord::createdAt)
                        .thenComparingLong(StorageExpansionExecutionRecord::id))
                .limit(Math.max(1, batchSize))
                .toList();
        for (StorageExpansionExecutionRecord execution : candidates) {
            executions.put(execution.id(), new StorageExpansionExecutionRecord(
                    execution.id(),
                    execution.requestId(),
                    execution.executionType(),
                    execution.result(),
                    execution.command(),
                    redactedOutput,
                    execution.externalUrl(),
                    execution.artifactSha256(),
                    execution.exitCode(),
                    execution.timedOut(),
                    execution.notes(),
                    execution.createdBy(),
                    execution.createdAt()
            ));
        }
        return candidates.size();
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private boolean hasRetainedOutputBefore(StorageExpansionExecutionRecord execution, OffsetDateTime cutoff) {
        return execution.createdAt().isBefore(cutoff)
                && execution.output() != null
                && !execution.output().isBlank()
                && !execution.output().startsWith("[redacted by execution log retention policy]");
    }
}
