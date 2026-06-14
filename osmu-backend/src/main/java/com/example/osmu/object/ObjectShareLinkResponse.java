package com.example.osmu.object;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.OffsetDateTime;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ObjectShareLinkResponse(
        long id,
        String bucketName,
        String key,
        String status,
        OffsetDateTime expiresAt,
        String note,
        Integer maxDownloads,
        long downloadCount,
        OffsetDateTime lastAccessedAt,
        boolean passwordProtected,
        String allowedIpCidrs,
        boolean ipRestricted,
        long createdByUserId,
        OffsetDateTime createdAt,
        OffsetDateTime revokedAt,
        String token,
        String url
) {

    public static ObjectShareLinkResponse of(ObjectShareLink link, String token, String url) {
        return new ObjectShareLinkResponse(
                link.id(),
                link.bucketName(),
                link.objectKey(),
                link.status(),
                link.expiresAt(),
                link.note(),
                link.maxDownloads(),
                link.downloadCount(),
                link.lastAccessedAt(),
                link.passwordProtected(),
                link.allowedIpCidrs().isBlank() ? null : link.allowedIpCidrs(),
                link.ipRestricted(),
                link.createdByUserId(),
                link.createdAt(),
                link.revokedAt(),
                token,
                url
        );
    }
}
