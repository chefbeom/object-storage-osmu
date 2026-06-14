package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectShareLink;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectShareLinkRepository implements ObjectShareLinkRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, ObjectShareLink> linksById = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, Long> idsByTokenHash = new ConcurrentHashMap<>();

    @Override
    public Optional<ObjectShareLink> findById(long id) {
        return Optional.ofNullable(linksById.get(id));
    }

    @Override
    public Optional<ObjectShareLink> findByTokenHash(String tokenHash) {
        Long id = idsByTokenHash.get(tokenHash);
        return id == null ? Optional.empty() : findById(id);
    }

    @Override
    public List<ObjectShareLink> findByBucket(String bucketName, int limit) {
        return linksById.values().stream()
                .filter(link -> link.bucketName().equals(bucketName))
                .sorted(Comparator.comparing(ObjectShareLink::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public List<ObjectShareLink> findByBucketAndKey(String bucketName, String objectKey, int limit) {
        return linksById.values().stream()
                .filter(link -> link.bucketName().equals(bucketName) && link.objectKey().equals(objectKey))
                .sorted(Comparator.comparing(ObjectShareLink::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public List<ObjectShareLink> findAll() {
        return linksById.values().stream()
                .sorted(Comparator.comparing(ObjectShareLink::id).reversed())
                .toList();
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public ObjectShareLink save(ObjectShareLink link) {
        linksById.put(link.id(), link);
        idsByTokenHash.put(link.tokenHash(), link.id());
        return link;
    }

    @Override
    public ObjectShareLink recordDownload(ObjectShareLink link, OffsetDateTime accessedAt) {
        ObjectShareLink updated = link.withDownloadRecorded(accessedAt);
        linksById.put(updated.id(), updated);
        idsByTokenHash.put(updated.tokenHash(), updated.id());
        return updated;
    }

    @Override
    public int expireActiveBefore(String bucketName, OffsetDateTime expiresAt) {
        return expireActiveBefore(expiresAt, bucketName);
    }

    @Override
    public int expireActiveBefore(OffsetDateTime expiresAt) {
        return expireActiveBefore(expiresAt, null);
    }

    private int expireActiveBefore(OffsetDateTime expiresAt, String bucketName) {
        AtomicInteger expiredCount = new AtomicInteger();
        linksById.replaceAll((id, link) -> {
            if ((bucketName != null && !link.bucketName().equals(bucketName))
                    || !"ACTIVE".equals(link.status())
                    || link.expiresAt().isAfter(expiresAt)) {
                return link;
            }
            expiredCount.incrementAndGet();
            return link.withStatus("EXPIRED", null);
        });
        return expiredCount.get();
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
