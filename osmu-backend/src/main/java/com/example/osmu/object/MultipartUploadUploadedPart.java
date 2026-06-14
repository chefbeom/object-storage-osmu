package com.example.osmu.object;

public record MultipartUploadUploadedPart(
        int partNumber,
        String etag,
        long sizeBytes
) {
}
