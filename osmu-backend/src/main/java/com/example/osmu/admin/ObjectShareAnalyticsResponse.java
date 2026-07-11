package com.example.osmu.admin;

import com.example.osmu.object.ObjectShareLinkAnalytics;
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

    public static ObjectShareAnalyticsResponse of(ObjectShareLinkAnalytics analytics) {
        return new ObjectShareAnalyticsResponse(
                analytics.totalLinks(),
                analytics.activeLinks(),
                analytics.expiredLinks(),
                analytics.revokedLinks(),
                analytics.limitReachedLinks(),
                analytics.passwordProtectedLinks(),
                analytics.ipRestrictedLinks(),
                analytics.totalDownloads(),
                analytics.lastAccessedAt(),
                analytics.recentLinks().stream()
                        .map(link -> ObjectShareLinkResponse.of(link, null, null))
                        .toList()
        );
    }
}
