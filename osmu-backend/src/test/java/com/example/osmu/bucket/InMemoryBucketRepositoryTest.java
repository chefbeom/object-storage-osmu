package com.example.osmu.bucket;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.bucket.repository.InMemoryBucketRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class InMemoryBucketRepositoryTest {

    @Test
    void summarizesUsageAndOwnerUsage() {
        InMemoryBucketRepository repository = new InMemoryBucketRepository();
        repository.save(bucket(1L, "alpha", "USER", 10L, 1_000L, 300L, 3L));
        repository.save(bucket(2L, "beta", "USER", 10L, 2_000L, 700L, 7L));
        repository.save(bucket(3L, "gamma", "ORG", 20L, 4_000L, 1_500L, 15L));

        BucketUsageSummary summary = repository.summarizeUsage();

        assertThat(summary).isEqualTo(new BucketUsageSummary(3L, 7_000L, 2_500L, 25L));
        assertThat(repository.sumUsedBytesByOwner("USER", 10L)).isEqualTo(1_000L);
        assertThat(repository.sumUsedBytesByOwner("ORG", 20L)).isEqualTo(1_500L);
        assertThat(repository.sumUsedBytesByOwner("USER", 99L)).isZero();
        assertThat(repository.summarizeUsageByOwners("USER", List.of(10L, 99L)))
                .containsExactly(new BucketOwnerUsageSummary(10L, 2L, 3_000L, 1_000L, 10L));
        assertThat(repository.findByIds(List.of(3L, 1L, 99L)))
                .extracting(BucketRecord::name)
                .containsExactly("alpha", "gamma");
        assertThat(repository.findByOwners("ORG", List.of(20L, 99L)))
                .extracting(BucketRecord::name)
                .containsExactly("gamma");
        assertThat(repository.findById(2L)).contains(bucket(2L, "beta", "USER", 10L, 2_000L, 700L, 7L));
        assertThat(repository.existsByOwner("ORG", 20L)).isTrue();
        assertThat(repository.existsByOwner("ORG", 99L)).isFalse();
    }

    private BucketRecord bucket(
            long id,
            String name,
            String ownerType,
            long ownerId,
            long quotaBytes,
            long usedBytes,
            long objectCount
    ) {
        return new BucketRecord(
                id,
                name,
                ownerType,
                ownerId,
                quotaBytes,
                usedBytes,
                objectCount,
                OffsetDateTime.parse("2026-07-10T00:00:00Z")
        );
    }
}
