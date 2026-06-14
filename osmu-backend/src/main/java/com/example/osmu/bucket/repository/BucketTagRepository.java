package com.example.osmu.bucket.repository;

import java.util.Map;

public interface BucketTagRepository {

    Map<String, String> findByBucketName(String bucketName);

    Map<String, String> replace(String bucketName, Map<String, String> tags);

    void delete(String bucketName);
}
