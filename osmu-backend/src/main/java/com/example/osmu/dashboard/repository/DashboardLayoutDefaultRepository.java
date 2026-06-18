package com.example.osmu.dashboard.repository;

import com.example.osmu.dashboard.DashboardLayoutDefaultRecord;
import java.util.List;
import java.util.Optional;

public interface DashboardLayoutDefaultRepository {

    List<DashboardLayoutDefaultRecord> findAll();

    Optional<DashboardLayoutDefaultRecord> findByTarget(String targetType, String targetId);

    DashboardLayoutDefaultRecord save(DashboardLayoutDefaultRecord record);

    boolean deleteByTarget(String targetType, String targetId);

    boolean isHealthy();
}
