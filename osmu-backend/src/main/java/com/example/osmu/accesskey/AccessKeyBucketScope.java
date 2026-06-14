package com.example.osmu.accesskey;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

public record AccessKeyBucketScope(
        @NotBlank String bucketName,
        @NotEmpty @Size(max = 3) List<@NotBlank String> permissions
) {
}
