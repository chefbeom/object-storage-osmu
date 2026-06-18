package com.example.osmu.storageprofile;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.util.Locale;
import java.util.Set;

public enum StorageProfileCode {
    PERFORMANCE,
    STANDARD,
    DURABLE;

    private static final Set<String> ALIASES_PERFORMANCE = Set.of("PERFORMANCE", "RAID0", "RAID0_LIKE", "RAID0-LIKE");
    private static final Set<String> ALIASES_STANDARD = Set.of("STANDARD", "ERASURE", "ERASURE_CODING", "EC");
    private static final Set<String> ALIASES_DURABLE = Set.of("DURABLE", "HIGH_PARITY", "HIGH-PARITY");

    public static StorageProfileCode parse(String rawValue) {
        String value = rawValue == null ? "" : rawValue.trim().toUpperCase(Locale.ROOT);
        if (ALIASES_PERFORMANCE.contains(value)) {
            return PERFORMANCE;
        }
        if (ALIASES_STANDARD.contains(value)) {
            return STANDARD;
        }
        if (ALIASES_DURABLE.contains(value)) {
            return DURABLE;
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid storage profile.");
    }
}
