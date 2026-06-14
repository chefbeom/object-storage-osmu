package com.example.osmu.audit.repository;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogQuery;
import java.util.List;

public interface AuditLogRepository {

    List<AuditLogEntry> findRecent(int limit);

    List<AuditLogEntry> find(AuditLogQuery query);

    long nextId();

    AuditLogEntry save(AuditLogEntry entry);

    boolean isHealthy();
}
