package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.object.repository.InMemoryObjectShareLinkRepository;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class InMemoryObjectShareLinkRepositoryTest {

    private static final OffsetDateTime BASE_TIME = OffsetDateTime.parse("2026-07-10T00:00:00Z");

    @Test
    void analyticsFiltersAggregatesAndBoundsRecentLinks() {
        InMemoryObjectShareLinkRepository repository = new InMemoryObjectShareLinkRepository();
        repository.save(link(1L, "alpha", "ACTIVE", "password-hash", "203.0.113.0/24", 3L, BASE_TIME.plusMinutes(1)));
        repository.save(link(2L, "alpha", "EXPIRED", "", "", 2L, BASE_TIME.plusMinutes(2)));
        repository.save(link(3L, "beta", "ACTIVE", "password-hash", "", 5L, BASE_TIME.plusMinutes(3)));
        repository.save(link(4L, "alpha", "REVOKED", "", "", 1L, null));

        ObjectShareLinkAnalytics alpha = repository.analytics("alpha", "", 2);

        assertThat(alpha.totalLinks()).isEqualTo(3L);
        assertThat(alpha.activeLinks()).isEqualTo(1L);
        assertThat(alpha.expiredLinks()).isEqualTo(1L);
        assertThat(alpha.revokedLinks()).isEqualTo(1L);
        assertThat(alpha.limitReachedLinks()).isZero();
        assertThat(alpha.passwordProtectedLinks()).isEqualTo(1L);
        assertThat(alpha.ipRestrictedLinks()).isEqualTo(1L);
        assertThat(alpha.totalDownloads()).isEqualTo(6L);
        assertThat(alpha.lastAccessedAt()).isEqualTo(BASE_TIME.plusMinutes(2));
        assertThat(alpha.recentLinks())
                .extracting(ObjectShareLink::id)
                .containsExactly(4L, 2L);

        ObjectShareLinkAnalytics active = repository.analytics("", "ACTIVE", 10);

        assertThat(active.totalLinks()).isEqualTo(2L);
        assertThat(active.activeLinks()).isEqualTo(2L);
        assertThat(active.recentLinks())
                .extracting(ObjectShareLink::id)
                .containsExactly(3L, 1L);
    }

    private ObjectShareLink link(
            long id,
            String bucketName,
            String status,
            String passwordHash,
            String allowedIpCidrs,
            long downloadCount,
            OffsetDateTime lastAccessedAt
    ) {
        return new ObjectShareLink(
                id,
                "token-hash-" + id,
                passwordHash,
                allowedIpCidrs,
                bucketName,
                "object-" + id + ".txt",
                7L,
                status,
                BASE_TIME.plusHours(1),
                "",
                null,
                downloadCount,
                lastAccessedAt,
                BASE_TIME.plusSeconds(id),
                "REVOKED".equals(status) ? BASE_TIME.plusMinutes(4) : null
        );
    }
}