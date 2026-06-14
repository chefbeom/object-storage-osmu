package com.example.osmu.object;

import jakarta.validation.constraints.NotBlank;

public record PresignedUploadCompleteRequest(
        @NotBlank String uploadId,
        @NotBlank String key
) {
}
