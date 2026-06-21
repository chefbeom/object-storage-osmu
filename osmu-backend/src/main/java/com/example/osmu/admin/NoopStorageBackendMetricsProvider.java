package com.example.osmu.admin;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.storage.metrics", name = "enabled", havingValue = "false", matchIfMissing = true)
public class NoopStorageBackendMetricsProvider implements StorageBackendMetricsProvider {

    @Override
    public StorageBackendMetricsSnapshot snapshot() {
        return StorageBackendMetricsSnapshot.disabled();
    }
}
