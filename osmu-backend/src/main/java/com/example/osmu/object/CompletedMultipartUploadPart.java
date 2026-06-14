package com.example.osmu.object;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.Map;

public record CompletedMultipartUploadPart(
        @Min(1) int partNumber,
        @NotBlank String etag,
        Map<String, String> checksums
) {

    public CompletedMultipartUploadPart(int partNumber, String etag) {
        this(partNumber, etag, Map.of());
    }

    public CompletedMultipartUploadPart {
        checksums = checksums == null ? Map.of() : Map.copyOf(checksums);
    }
}
