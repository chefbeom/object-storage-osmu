package com.example.osmu.storage;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.util.Locale;

public enum BucketVersioningStatus {
    ENABLED,
    SUSPENDED;

    public static BucketVersioningStatus fromRequest(String value) {
        String normalized = value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
        if (normalized.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket versioning status is required.");
        }
        try {
            return BucketVersioningStatus.valueOf(normalized);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket versioning status must be ENABLED or SUSPENDED.");
        }
    }
}
