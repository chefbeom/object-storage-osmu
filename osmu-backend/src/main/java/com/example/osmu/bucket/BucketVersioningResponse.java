package com.example.osmu.bucket;

import com.example.osmu.storage.BucketVersioningStatus;

public record BucketVersioningResponse(
        String bucketName,
        String status,
        boolean storageBacked,
        String scopePolicy
) {

    public static BucketVersioningResponse of(String bucketName, BucketVersioningStatus status) {
        return new BucketVersioningResponse(
                bucketName,
                status.name(),
                true,
                "OSMU bucket versioning management controls the underlying storage bucket state. It is not AWS S3 versioning parity."
        );
    }
}
