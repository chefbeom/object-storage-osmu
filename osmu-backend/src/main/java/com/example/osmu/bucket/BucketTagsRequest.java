package com.example.osmu.bucket;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public record BucketTagsRequest(
        Map<String, String> tags
) {
    public BucketTagsRequest {
        tags = tags == null ? Map.of() : Collections.unmodifiableMap(new LinkedHashMap<>(tags));
    }
}
