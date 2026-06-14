package com.example.osmu.bucket;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;

public record CreateBucketRequest(
        @NotBlank String name,
        @PositiveOrZero Long quotaBytes,
        String ownerType,
        Long ownerId
) {
}
