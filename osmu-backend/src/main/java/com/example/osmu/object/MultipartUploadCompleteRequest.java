package com.example.osmu.object;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record MultipartUploadCompleteRequest(
        @NotBlank String uploadId,
        @NotBlank String key,
        @NotEmpty List<@Valid CompletedMultipartUploadPart> parts
) {
}
