package com.example.osmu.object;

public record PresignedObjectUrl(
        String url,
        String method,
        int expiresInSeconds,
        String uploadId
) {
}
