package com.example.osmu.admin;

import com.example.osmu.object.ObjectShareLinkResponse;
import java.time.OffsetDateTime;
import java.util.List;

public record ObjectShareAnalyticsResponse(
        long totalLinks,
        long activeLinks,
        long expiredLinks,
        long revokedLinks,
        long limitReachedLinks,
        long passwordProtectedLinks,
        long ipRestrictedLinks,
        long totalDownloads,
        OffsetDateTime lastAccessedAt,
        List<ObjectShareLinkResponse> recentLinks
) {
}
