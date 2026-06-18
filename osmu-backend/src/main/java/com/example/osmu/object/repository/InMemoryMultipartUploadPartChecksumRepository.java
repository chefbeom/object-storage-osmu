package com.example.osmu.object.repository;

import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryMultipartUploadPartChecksumRepository implements MultipartUploadPartChecksumRepository {

    private final ConcurrentMap<String, ConcurrentMap<Integer, Map<String, String>>> checksumsByUpload =
            new ConcurrentHashMap<>();

    @Override
    public void save(String uploadId, int partNumber, Map<String, String> checksums) {
        if (uploadId == null || uploadId.isBlank() || checksums == null || checksums.isEmpty()) {
            return;
        }
        checksumsByUpload.computeIfAbsent(uploadId, key -> new ConcurrentHashMap<>())
                .put(partNumber, Map.copyOf(checksums));
    }

    @Override
    public Map<Integer, Map<String, String>> findByUploadId(String uploadId) {
        ConcurrentMap<Integer, Map<String, String>> checksums = checksumsByUpload.get(uploadId);
        if (checksums == null || checksums.isEmpty()) {
            return Map.of();
        }
        Map<Integer, Map<String, String>> sorted = new TreeMap<>();
        checksums.forEach((partNumber, values) -> sorted.put(partNumber, Map.copyOf(values)));
        return Map.copyOf(sorted);
    }

    @Override
    public void deleteByUploadId(String uploadId) {
        checksumsByUpload.remove(uploadId);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
