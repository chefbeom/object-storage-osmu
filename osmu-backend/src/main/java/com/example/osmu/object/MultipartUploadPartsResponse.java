package com.example.osmu.object;

import java.util.List;

public record MultipartUploadPartsResponse(
        String uploadId,
        String key,
        long sizeBytes,
        long partSizeBytes,
        int partCount,
        List<MultipartUploadUploadedPart> parts
) {
}
