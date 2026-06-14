package com.example.osmu.object;

import jakarta.validation.constraints.NotBlank;

public record MultipartUploadAbortRequest(
        @NotBlank String uploadId,
        @NotBlank String key
) {
}
