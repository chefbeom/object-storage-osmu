package com.example.osmu.dashboard.repository;

import com.example.osmu.dashboard.DashboardLayoutRecord;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryDashboardLayoutRepository implements DashboardLayoutRepository {

    private final ConcurrentMap<String, DashboardLayoutRecord> layouts = new ConcurrentHashMap<>();

    @Override
    public Optional<DashboardLayoutRecord> findByUserIdAndScope(long userId, String scope) {
        return Optional.ofNullable(layouts.get(key(userId, scope)));
    }

    @Override
    public DashboardLayoutRecord save(DashboardLayoutRecord layout) {
        layouts.put(key(layout.userId(), layout.scope()), layout);
        return layout;
    }

    @Override
    public void deleteByUserIdAndScope(long userId, String scope) {
        layouts.remove(key(userId, scope));
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private String key(long userId, String scope) {
        return userId + ":" + scope;
    }
}
