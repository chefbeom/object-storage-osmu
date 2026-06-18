package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketPermissionRecord;
import java.util.List;
import java.util.Optional;

public interface BucketPermissionRepository {

    List<BucketPermissionRecord> findByBucketId(long bucketId);

    Optional<BucketPermissionRecord> findById(long id);

    boolean exists(long bucketId, String subjectType, long subjectId, String permission);

    long nextId();

    BucketPermissionRecord save(BucketPermissionRecord permission);

    void deleteById(long id);

    void deleteByBucketId(long bucketId);

    int deleteBySubject(String subjectType, long subjectId);

    boolean isHealthy();
}
