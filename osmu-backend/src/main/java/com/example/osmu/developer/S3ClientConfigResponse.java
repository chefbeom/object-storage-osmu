package com.example.osmu.developer;

import java.util.List;

public record S3ClientConfigResponse(
        String endpoint,
        String region,
        String signatureVersion,
        String service,
        boolean pathStyleSupported,
        boolean virtualHostedStyleEnabled,
        List<String> virtualHostedStyleDomainSuffixes
) {
}
