package com.example.osmu.accesskey;

import java.util.List;

public record CreateAccessKeyResponse(
        long id,
        String name,
        String accessKey,
        String secretKey,
        String policyName,
        String policyDocument,
        List<String> allowedBuckets,
        List<String> permissions,
        List<AccessKeyBucketScope> bucketScopes
) {
}
