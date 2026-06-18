package com.example.osmu.accesskey;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.Size;
import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import java.util.List;

public record CreateAccessKeyRequest(
        @NotBlank String name,
        @Size(max = 50) List<@NotBlank String> allowedBuckets,
        @Size(max = 4) List<@NotBlank String> permissions,
        @Size(max = 50) List<@Valid AccessKeyBucketScope> bucketScopes,
        @Future OffsetDateTime expiresAt
) {
}
