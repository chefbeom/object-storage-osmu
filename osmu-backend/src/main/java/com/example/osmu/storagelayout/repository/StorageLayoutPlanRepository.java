package com.example.osmu.storagelayout.repository;

import com.example.osmu.storagelayout.StorageLayoutPlanRecord;
import java.util.List;
import java.util.Optional;

public interface StorageLayoutPlanRepository {

    List<StorageLayoutPlanRecord> findPage(List<String> statuses, Long cursorId, int limit);

    Optional<StorageLayoutPlanRecord> findById(long id);

    long nextId();

    StorageLayoutPlanRecord save(StorageLayoutPlanRecord plan);

    boolean isHealthy();
}
