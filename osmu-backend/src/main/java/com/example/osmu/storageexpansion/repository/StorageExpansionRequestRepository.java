package com.example.osmu.storageexpansion.repository;

import com.example.osmu.storageexpansion.StorageExpansionRequestAggregate;
import com.example.osmu.storageexpansion.StorageExpansionRequestRecord;
import java.util.List;
import java.util.Optional;

public interface StorageExpansionRequestRepository {

    List<StorageExpansionRequestRecord> findAll();

    StorageExpansionRequestAggregate aggregate();

    Optional<StorageExpansionRequestRecord> findLatest();

    Optional<StorageExpansionRequestRecord> findById(long id);

    long nextId();

    StorageExpansionRequestRecord save(StorageExpansionRequestRecord request);

    boolean isHealthy();
}
