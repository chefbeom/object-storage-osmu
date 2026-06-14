package com.example.osmu.object;

import jakarta.validation.constraints.NotBlank;

public record ObjectTagsUpdateRequest(
        @NotBlank
        String key,
        String tags
) {
}
