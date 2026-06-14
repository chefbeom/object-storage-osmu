package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketRecord;
import java.util.List;
import java.util.Optional;

public interface BucketRepository {

    List<BucketRecord> findAll();

    Optional<BucketRecord> findByName(String bucketName);

    boolean existsByName(String bucketName);

    long nextId();

    BucketRecord save(BucketRecord bucket);

    void deleteByName(String bucketName);

    boolean isHealthy();
}
