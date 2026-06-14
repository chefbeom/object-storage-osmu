package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectShareLink;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface ObjectShareLinkRepository {

    Optional<ObjectShareLink> findById(long id);

    Optional<ObjectShareLink> findByTokenHash(String tokenHash);

    List<ObjectShareLink> findByBucket(String bucketName, int limit);

    List<ObjectShareLink> findByBucketAndKey(String bucketName, String objectKey, int limit);

    List<ObjectShareLink> findAll();

    long nextId();

    ObjectShareLink save(ObjectShareLink link);

    ObjectShareLink recordDownload(ObjectShareLink link, OffsetDateTime accessedAt);

    int expireActiveBefore(String bucketName, OffsetDateTime expiresAt);

    int expireActiveBefore(OffsetDateTime expiresAt);

    boolean isHealthy();
}
