package com.example.osmu.quota.repository;

import com.example.osmu.quota.QuotaPolicy;
import com.example.osmu.quota.QuotaPolicyPageCursor;
import com.example.osmu.quota.QuotaPolicyHistory;
import java.util.List;
import java.util.Optional;

public interface QuotaPolicyRepository {

    List<QuotaPolicy> findPage(QuotaPolicyPageCursor cursor, int limit);

    List<QuotaPolicy> findAllForDashboardSummary();

    List<QuotaPolicyHistory> findHistory(int limit);

    Optional<QuotaPolicy> findByTarget(String targetType, long targetId);

    long nextId();

    long nextHistoryId();

    QuotaPolicy save(QuotaPolicy policy);

    QuotaPolicyHistory saveHistory(QuotaPolicyHistory history);

    void deleteByTarget(String targetType, long targetId);

    boolean isHealthy();
}
