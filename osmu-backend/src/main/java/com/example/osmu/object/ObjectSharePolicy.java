package com.example.osmu.object;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.OffsetDateTime;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ObjectSharePolicy(
        boolean requirePassword,
        boolean requireIpAllowlist,
        int maxExpiresSeconds,
        Integer maxDownloadsLimit,
        OffsetDateTime updatedAt
) {
    public static final int DEFAULT_MAX_EXPIRES_SECONDS = 7 * 24 * 60 * 60;

    public static ObjectSharePolicy defaults() {
        return new ObjectSharePolicy(false, false, DEFAULT_MAX_EXPIRES_SECONDS, null, null);
    }
}
