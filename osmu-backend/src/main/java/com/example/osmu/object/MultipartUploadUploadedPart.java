package com.example.osmu.object;

import java.util.Map;

public record MultipartUploadUploadedPart(
        int partNumber,
        String etag,
        long sizeBytes,
        Map<String, String> checksums
) {

    public MultipartUploadUploadedPart(int partNumber, String etag, long sizeBytes) {
        this(partNumber, etag, sizeBytes, Map.of());
    }

    public MultipartUploadUploadedPart {
        checksums = checksums == null ? Map.of() : Map.copyOf(checksums);
    }

    public MultipartUploadUploadedPart withChecksums(Map<String, String> nextChecksums) {
        return new MultipartUploadUploadedPart(partNumber, etag, sizeBytes, nextChecksums);
    }
}
