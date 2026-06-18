package com.example.osmu.accesskey.repository;

import com.example.osmu.accesskey.AccessKeyBucketScope;
import com.example.osmu.accesskey.AccessKeyCredential;
import com.example.osmu.accesskey.AccessKeyEntity;
import com.example.osmu.accesskey.AccessKeyRecord;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryAccessKeyRepository implements AccessKeyRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, AccessKeyEntity> accessKeys = new ConcurrentHashMap<>();

    @Override
    public List<AccessKeyRecord> findAllRecords() {
        return accessKeys.values().stream()
                .map(AccessKeyEntity::toRecord)
                .sorted(Comparator.comparing(AccessKeyRecord::id))
                .toList();
    }

    @Override
    public List<AccessKeyRecord> findRecordsByOwnerId(long ownerId) {
        return accessKeys.values().stream()
                .filter(key -> key.ownerId() == ownerId)
                .map(AccessKeyEntity::toRecord)
                .sorted(Comparator.comparing(AccessKeyRecord::id))
                .toList();
    }

    @Override
    public Optional<AccessKeyRecord> findRecordById(long id) {
        return Optional.ofNullable(accessKeys.get(id)).map(AccessKeyEntity::toRecord);
    }

    @Override
    public Optional<AccessKeyCredential> findCredentialByAccessKey(String accessKey) {
        return accessKeys.values().stream()
                .filter(key -> key.accessKey().equals(accessKey))
                .findFirst()
                .map(this::credential);
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public AccessKeyRecord save(AccessKeyEntity accessKey) {
        accessKeys.put(accessKey.id(), accessKey);
        return accessKey.toRecord();
    }

    @Override
    public void updateScope(long id, List<String> allowedBuckets, List<String> permissions, List<AccessKeyBucketScope> bucketScopes) {
        accessKeys.computeIfPresent(id, (keyId, existing) -> new AccessKeyEntity(
                existing.id(),
                existing.ownerId(),
                existing.name(),
                existing.accessKey(),
                existing.secretKeyHash(),
                existing.secretKeyCiphertext(),
                allowedBuckets,
                permissions,
                bucketScopes,
                existing.status(),
                existing.createdAt(),
                existing.expiresAt(),
                existing.lastUsedAt()
        ));
    }

    @Override
    public void updateStatus(long id, String status) {
        accessKeys.computeIfPresent(id, (keyId, existing) -> new AccessKeyEntity(
                existing.id(),
                existing.ownerId(),
                existing.name(),
                existing.accessKey(),
                existing.secretKeyHash(),
                existing.secretKeyCiphertext(),
                existing.allowedBuckets(),
                existing.permissions(),
                existing.bucketScopes(),
                status,
                existing.createdAt(),
                existing.expiresAt(),
                existing.lastUsedAt()
        ));
    }

    @Override
    public void updateSecret(long id, String secretKeyHash, String secretKeyCiphertext) {
        accessKeys.computeIfPresent(id, (keyId, existing) -> new AccessKeyEntity(
                existing.id(),
                existing.ownerId(),
                existing.name(),
                existing.accessKey(),
                secretKeyHash,
                secretKeyCiphertext,
                existing.allowedBuckets(),
                existing.permissions(),
                existing.bucketScopes(),
                existing.status(),
                existing.createdAt(),
                existing.expiresAt(),
                existing.lastUsedAt()
        ));
    }

    @Override
    public void markUsed(long id, OffsetDateTime usedAt) {
        accessKeys.computeIfPresent(id, (keyId, existing) -> new AccessKeyEntity(
                existing.id(),
                existing.ownerId(),
                existing.name(),
                existing.accessKey(),
                existing.secretKeyHash(),
                existing.secretKeyCiphertext(),
                existing.allowedBuckets(),
                existing.permissions(),
                existing.bucketScopes(),
                existing.status(),
                existing.createdAt(),
                existing.expiresAt(),
                usedAt
        ));
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private AccessKeyCredential credential(AccessKeyEntity entity) {
        return new AccessKeyCredential(
                entity.id(),
                entity.ownerId(),
                entity.accessKey(),
                entity.secretKeyHash(),
                entity.secretKeyCiphertext(),
                entity.bucketScopes(),
                entity.status(),
                entity.expiresAt()
        );
    }
}
