package com.example.osmu.object;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

public record MultipartUploadCreateRequest(
        @NotBlank String key,
        String contentType,
        @Positive Long sizeBytes,
        @Positive Long partSizeBytes,
        @Min(60) @Max(604800) Integer expiresInSeconds,
        String tags,
        String checksumAlgorithm,
        String checksumType
) {
    public MultipartUploadCreateRequest(
            String key,
            String contentType,
            Long sizeBytes,
            Long partSizeBytes,
            Integer expiresInSeconds,
            String tags
    ) {
        this(key, contentType, sizeBytes, partSizeBytes, expiresInSeconds, tags, "", "");
    }
}
