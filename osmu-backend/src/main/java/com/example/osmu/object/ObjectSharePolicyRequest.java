package com.example.osmu.object;

public record ObjectSharePolicyRequest(
        Boolean requirePassword,
        Boolean requireIpAllowlist,
        Integer maxExpiresSeconds,
        Integer maxDownloadsLimit,
        String reason
) {
}
