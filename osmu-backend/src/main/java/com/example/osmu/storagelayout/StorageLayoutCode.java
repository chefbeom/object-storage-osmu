package com.example.osmu.storagelayout;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.util.Locale;

public enum StorageLayoutCode {
    JBOD,
    RAID0,
    RAID1,
    RAID5,
    RAID6,
    RAID10;

    public static StorageLayoutCode parse(String rawValue) {
        String normalized = rawValue == null
                ? ""
                : rawValue.trim().toUpperCase(Locale.ROOT).replace("-", "").replace("_", "");
        return switch (normalized) {
            case "JBOD" -> JBOD;
            case "RAID0" -> RAID0;
            case "RAID1" -> RAID1;
            case "RAID5" -> RAID5;
            case "RAID6" -> RAID6;
            case "RAID10" -> RAID10;
            default -> throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "Storage layout must be one of JBOD, RAID0, RAID1, RAID5, RAID6, or RAID10."
            );
        };
    }
}
