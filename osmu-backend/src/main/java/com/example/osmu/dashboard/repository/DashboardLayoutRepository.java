package com.example.osmu.dashboard.repository;

import com.example.osmu.dashboard.DashboardLayoutRecord;
import java.util.Optional;

public interface DashboardLayoutRepository {

    Optional<DashboardLayoutRecord> findByUserIdAndScope(long userId, String scope);

    DashboardLayoutRecord save(DashboardLayoutRecord layout);

    void deleteByUserIdAndScope(long userId, String scope);

    boolean isHealthy();
}
