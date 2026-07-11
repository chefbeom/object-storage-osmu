package com.example.osmu.storageprofile.repository;

import com.example.osmu.storageprofile.StorageProfileRequestRecord;
import java.util.List;
import java.util.Optional;

public interface StorageProfileRequestRepository {

    List<StorageProfileRequestRecord> findPage(List<String> statuses, Long cursorId, int limit);

    List<StorageProfileRequestRecord> findPageByBucketName(String bucketName, Long cursorId, int limit);

    List<StorageProfileRequestRecord> findPageByBucketNames(List<String> bucketNames, Long cursorId, int limit);

    Optional<StorageProfileRequestRecord> findLatestByBucketName(String bucketName);

    Optional<StorageProfileRequestRecord> findById(long id);

    long nextId();

    StorageProfileRequestRecord save(StorageProfileRequestRecord request);

    boolean isHealthy();
}
