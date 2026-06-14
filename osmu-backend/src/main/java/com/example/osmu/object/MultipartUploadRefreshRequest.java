package com.example.osmu.object;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record MultipartUploadRefreshRequest(
        @NotBlank String uploadId,
        @NotBlank String key,
        @Min(60) @Max(604800) Integer expiresInSeconds
) {
}
