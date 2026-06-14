package com.example.osmu.bucket;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public record BucketTagsResponse(
        String bucketName,
        Map<String, String> tags,
        int tagCount
) {
    public BucketTagsResponse {
        tags = tags == null ? Map.of() : Collections.unmodifiableMap(new LinkedHashMap<>(tags));
    }

    public static BucketTagsResponse of(String bucketName, Map<String, String> tags) {
        return new BucketTagsResponse(bucketName, tags, tags == null ? 0 : tags.size());
    }
}
