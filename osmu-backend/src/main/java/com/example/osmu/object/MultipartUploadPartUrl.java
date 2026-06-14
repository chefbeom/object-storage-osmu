package com.example.osmu.object;

public record MultipartUploadPartUrl(
        int partNumber,
        String url,
        String method,
        int expiresInSeconds,
        long startByte,
        long endByte
) {
}
