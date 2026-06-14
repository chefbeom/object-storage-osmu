package com.example.osmu.object;

import java.time.OffsetDateTime;

public record PresignedUploadSession(
        String uploadId,
        long userId,
        String bucketName,
        String objectKey,
        String tags,
        String uploadMode,
        String storageUploadId,
        long expectedSizeBytes,
        long partSizeBytes,
        int partCount,
        String status,
        long previousSizeBytes,
        boolean previousExists,
        OffsetDateTime expiresAt,
        OffsetDateTime createdAt,
        OffsetDateTime completedAt
) {
    public PresignedUploadSession {
        tags = tags == null ? "" : tags;
        uploadMode = uploadMode == null || uploadMode.isBlank() ? "PRESIGNED_PUT" : uploadMode;
    }
}
