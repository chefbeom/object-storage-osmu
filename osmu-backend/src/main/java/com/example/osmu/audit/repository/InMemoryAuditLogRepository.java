package com.example.osmu.audit.repository;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogQuery;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryAuditLogRepository implements AuditLogRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final CopyOnWriteArrayList<AuditLogEntry> entries = new CopyOnWriteArrayList<>();

    @Override
    public List<AuditLogEntry> findRecent(int limit) {
        return entries.stream()
                .sorted(Comparator.comparing(AuditLogEntry::id).reversed())
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public List<AuditLogEntry> find(AuditLogQuery query) {
        return entries.stream()
                .filter(entry -> query.eventType() == null || entry.eventType().equals(query.eventType()))
                .filter(entry -> query.actorId() == null || entry.actorId().equals(query.actorId()))
                .filter(entry -> query.requestId() == null || query.requestId().equals(entry.requestId()))
                .filter(entry -> query.targetType() == null || entry.targetType().equals(query.targetType()))
                .filter(entry -> query.targetId() == null || entry.targetId().equals(query.targetId()))
                .filter(entry -> query.result() == null || entry.result().equals(query.result()))
                .filter(entry -> query.cursor() == null || entry.id() < query.cursor())
                .filter(entry -> query.from() == null || !entry.createdAt().isBefore(query.from()))
                .filter(entry -> query.to() == null || !entry.createdAt().isAfter(query.to()))
                .sorted(Comparator.comparing(AuditLogEntry::id).reversed())
                .limit(Math.max(0, query.limit()))
                .toList();
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public AuditLogEntry save(AuditLogEntry entry) {
        entries.add(entry);
        return entry;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
