package com.example.osmu.dashboard.repository;

import com.example.osmu.dashboard.DashboardLayoutPresetRecord;
import java.util.List;
import java.util.Optional;

public interface DashboardLayoutPresetRepository {

    List<DashboardLayoutPresetRecord> findAll();

    Optional<DashboardLayoutPresetRecord> findById(String id);

    DashboardLayoutPresetRecord save(DashboardLayoutPresetRecord preset);

    boolean deleteById(String id);

    boolean isHealthy();
}
