package com.example.osmu.storageprofile.repository;

import com.example.osmu.storageprofile.StorageProfileAssignmentRecord;
import java.util.Optional;

public interface StorageProfileAssignmentRepository {


    Optional<StorageProfileAssignmentRecord> findByBucketName(String bucketName);

    StorageProfileAssignmentRecord save(StorageProfileAssignmentRecord assignment);

    void deleteByBucketName(String bucketName);

    boolean isHealthy();
}
