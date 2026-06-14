package com.example.osmu.object;

import java.time.OffsetDateTime;
import java.util.List;

public record MultipartUploadCreateResponse(
        String uploadId,
        String key,
        long sizeBytes,
        long partSizeBytes,
        int partCount,
        int expiresInSeconds,
        OffsetDateTime expiresAt,
        List<MultipartUploadPartUrl> parts
) {
}
