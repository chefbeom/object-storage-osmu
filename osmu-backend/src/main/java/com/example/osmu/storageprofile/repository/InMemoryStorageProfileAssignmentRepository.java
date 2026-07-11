package com.example.osmu.storageprofile.repository;

import com.example.osmu.storageprofile.StorageProfileAssignmentRecord;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryStorageProfileAssignmentRepository implements StorageProfileAssignmentRepository {

    private final ConcurrentMap<String, StorageProfileAssignmentRecord> assignments = new ConcurrentHashMap<>();


    @Override
    public Optional<StorageProfileAssignmentRecord> findByBucketName(String bucketName) {
        return Optional.ofNullable(assignments.get(bucketName));
    }

    @Override
    public StorageProfileAssignmentRecord save(StorageProfileAssignmentRecord assignment) {
        assignments.put(assignment.bucketName(), assignment);
        return assignment;
    }

    @Override
    public void deleteByBucketName(String bucketName) {
        assignments.remove(bucketName);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
