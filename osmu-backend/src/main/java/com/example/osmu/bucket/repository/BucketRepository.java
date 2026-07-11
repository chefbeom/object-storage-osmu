package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketOwnerUsageSummary;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketUsageSummary;
import java.util.List;
import java.util.Optional;

public interface BucketRepository {

    List<BucketRecord> findAll();

    List<BucketRecord> findAccessible(long userId, Long organizationId, List<Long> explicitBucketIds);

    List<BucketRecord> findByIds(List<Long> bucketIds);

    List<BucketRecord> findByOwners(String ownerType, List<Long> ownerIds);

    BucketUsageSummary summarizeUsage();

    long sumUsedBytesByOwner(String ownerType, long ownerId);

    List<BucketOwnerUsageSummary> summarizeUsageByOwners(String ownerType, List<Long> ownerIds);

    boolean existsByOwner(String ownerType, long ownerId);

    Optional<BucketRecord> findById(long bucketId);

    Optional<BucketRecord> findByName(String bucketName);

    boolean existsByName(String bucketName);

    long nextId();

    BucketRecord save(BucketRecord bucket);

    void deleteByName(String bucketName);

    boolean isHealthy();
}
