package com.example.osmu.object;

import java.time.OffsetDateTime;
import java.util.List;

public record ObjectShareLinkAnalytics(
        long totalLinks,
        long activeLinks,
        long expiredLinks,
        long revokedLinks,
        long limitReachedLinks,
        long passwordProtectedLinks,
        long ipRestrictedLinks,
        long totalDownloads,
        OffsetDateTime lastAccessedAt,
        List<ObjectShareLink> recentLinks
) {

    public ObjectShareLinkAnalytics {
        recentLinks = recentLinks == null ? List.of() : List.copyOf(recentLinks);
    }
}