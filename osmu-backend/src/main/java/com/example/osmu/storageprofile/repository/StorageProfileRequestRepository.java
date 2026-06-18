package com.example.osmu.storageprofile.repository;

import com.example.osmu.storageprofile.StorageProfileRequestRecord;
import java.util.List;
import java.util.Optional;

public interface StorageProfileRequestRepository {

    List<StorageProfileRequestRecord> findAll();

    List<StorageProfileRequestRecord> findByBucketName(String bucketName);

    Optional<StorageProfileRequestRecord> findLatestByBucketName(String bucketName);

    Optional<StorageProfileRequestRecord> findById(long id);

    long nextId();

    StorageProfileRequestRecord save(StorageProfileRequestRecord request);

    boolean isHealthy();
}
