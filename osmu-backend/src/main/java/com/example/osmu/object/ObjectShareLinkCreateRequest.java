package com.example.osmu.object;

public record ObjectShareLinkCreateRequest(
        String key,
        Integer expiresInSeconds,
        String note,
        Integer maxDownloads,
        String password,
        String allowedIpCidrs
) {
}
