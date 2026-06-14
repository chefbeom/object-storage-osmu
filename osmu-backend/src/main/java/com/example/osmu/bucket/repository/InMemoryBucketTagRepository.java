package com.example.osmu.bucket.repository;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryBucketTagRepository implements BucketTagRepository {

    private final ConcurrentMap<String, Map<String, String>> bucketTags = new ConcurrentHashMap<>();

    @Override
    public Map<String, String> findByBucketName(String bucketName) {
        return new LinkedHashMap<>(bucketTags.getOrDefault(bucketName, Map.of()));
    }

    @Override
    public Map<String, String> replace(String bucketName, Map<String, String> tags) {
        Map<String, String> copied = new LinkedHashMap<>(tags);
        if (copied.isEmpty()) {
            bucketTags.remove(bucketName);
            return Map.of();
        }
        bucketTags.put(bucketName, copied);
        return new LinkedHashMap<>(copied);
    }

    @Override
    public void delete(String bucketName) {
        bucketTags.remove(bucketName);
    }
}
