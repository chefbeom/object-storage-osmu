package com.example.osmu.object.repository;

import java.util.Map;

public interface MultipartUploadPartChecksumRepository {

    void save(String uploadId, int partNumber, Map<String, String> checksums);

    Map<Integer, Map<String, String>> findByUploadId(String uploadId);

    void deleteByUploadId(String uploadId);

    boolean isHealthy();
}
