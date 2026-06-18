package com.example.osmu.dashboard.repository;

import com.example.osmu.dashboard.DashboardLayoutDefaultRecord;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryDashboardLayoutDefaultRepository implements DashboardLayoutDefaultRepository {

    private final Map<String, DashboardLayoutDefaultRecord> records = new ConcurrentHashMap<>();

    @Override
    public List<DashboardLayoutDefaultRecord> findAll() {
        return records.values().stream()
                .sorted(Comparator.comparing(DashboardLayoutDefaultRecord::targetType)
                        .thenComparing(DashboardLayoutDefaultRecord::targetId))
                .toList();
    }

    @Override
    public Optional<DashboardLayoutDefaultRecord> findByTarget(String targetType, String targetId) {
        return Optional.ofNullable(records.get(key(targetType, targetId)));
    }

    @Override
    public DashboardLayoutDefaultRecord save(DashboardLayoutDefaultRecord record) {
        records.put(key(record.targetType(), record.targetId()), record);
        return record;
    }

    @Override
    public boolean deleteByTarget(String targetType, String targetId) {
        return records.remove(key(targetType, targetId)) != null;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private String key(String targetType, String targetId) {
        return targetType + ":" + targetId;
    }
}
