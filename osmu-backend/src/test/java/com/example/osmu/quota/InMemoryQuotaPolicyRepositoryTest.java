package com.example.osmu.quota;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

import com.example.osmu.quota.repository.InMemoryQuotaPolicyRepository;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class InMemoryQuotaPolicyRepositoryTest {

    @Test
    void findsBoundedCompositeCursorPageInStableOrder() {
        InMemoryQuotaPolicyRepository repository = new InMemoryQuotaPolicyRepository();
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        repository.save(new QuotaPolicy(1L, "USER", 10L, 1L, now, now));
        repository.save(new QuotaPolicy(2L, "ORGANIZATION", 20L, 1L, now, now));
        repository.save(new QuotaPolicy(3L, "BUCKET", 30L, 1L, now, now));

        assertThat(repository.findPage(null, 2))
                .extracting(QuotaPolicy::targetType, QuotaPolicy::targetId)
                .containsExactly(
                        tuple("BUCKET", 30L),
                        tuple("ORGANIZATION", 20L)
                );
        assertThat(repository.findPage(new QuotaPolicyPageCursor("ORGANIZATION", 20L), 2))
                .extracting(QuotaPolicy::targetType, QuotaPolicy::targetId)
                .containsExactly(tuple("USER", 10L));
    }
}