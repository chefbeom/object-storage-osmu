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
    @Override
    public String toString() {
        return "CreateAccessKeyResponse["
                + "id=" + id
                + ", name=" + name
                + ", accessKey=<redacted>"
                + ", secretKey=<redacted>"
                + ", policyName=" + policyName
                + ", policyDocument=<omitted>"
                + ", allowedBuckets=" + allowedBuckets
                + ", permissions=" + permissions
                + ", bucketScopes=" + bucketScopes
                + "]";
    }
}
