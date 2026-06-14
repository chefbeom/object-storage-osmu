package com.example.osmu.object;

import jakarta.validation.constraints.NotBlank;

public record MultipartUploadPartsRequest(
        @NotBlank String uploadId,
        @NotBlank String key
) {
}
