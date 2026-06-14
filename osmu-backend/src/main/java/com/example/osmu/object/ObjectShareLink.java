package com.example.osmu.object;

import java.time.OffsetDateTime;

public record ObjectShareLink(
        long id,
        String tokenHash,
        String passwordHash,
        String allowedIpCidrs,
        String bucketName,
        String objectKey,
        long createdByUserId,
        String status,
        OffsetDateTime expiresAt,
        String note,
        Integer maxDownloads,
        long downloadCount,
        OffsetDateTime lastAccessedAt,
        OffsetDateTime createdAt,
        OffsetDateTime revokedAt
) {

    public ObjectShareLink {
        passwordHash = passwordHash == null ? "" : passwordHash.trim();
        allowedIpCidrs = allowedIpCidrs == null ? "" : allowedIpCidrs.trim();
        note = note == null ? "" : note.trim();
    }

    public boolean passwordProtected() {
        return !passwordHash.isBlank();
    }

    public boolean ipRestricted() {
        return !allowedIpCidrs.isBlank();
    }

    public ObjectShareLink withStatus(String nextStatus, OffsetDateTime nextRevokedAt) {
        return new ObjectShareLink(
                id,
                tokenHash,
                passwordHash,
                allowedIpCidrs,
                bucketName,
                objectKey,
                createdByUserId,
                nextStatus,
                expiresAt,
                note,
                maxDownloads,
                downloadCount,
                lastAccessedAt,
                createdAt,
                nextRevokedAt
        );
    }

    public ObjectShareLink withDownloadRecorded(OffsetDateTime accessedAt) {
        return new ObjectShareLink(
                id,
                tokenHash,
                passwordHash,
                allowedIpCidrs,
                bucketName,
                objectKey,
                createdByUserId,
                status,
                expiresAt,
                note,
                maxDownloads,
                downloadCount + 1,
                accessedAt,
                createdAt,
                revokedAt
        );
    }
}
