package com.example.osmu.dashboard.repository;

import com.example.osmu.dashboard.DashboardLayoutPresetRecord;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryDashboardLayoutPresetRepository implements DashboardLayoutPresetRepository {

    private final ConcurrentMap<String, DashboardLayoutPresetRecord> presets = new ConcurrentHashMap<>();

    @Override
    public List<DashboardLayoutPresetRecord> findAll() {
        return presets.values().stream()
                .sorted(Comparator.comparing(DashboardLayoutPresetRecord::name, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    @Override
    public Optional<DashboardLayoutPresetRecord> findById(String id) {
        return Optional.ofNullable(presets.get(id));
    }

    @Override
    public DashboardLayoutPresetRecord save(DashboardLayoutPresetRecord preset) {
        presets.put(preset.id(), preset);
        return preset;
    }

    @Override
    public boolean deleteById(String id) {
        return presets.remove(id) != null;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
