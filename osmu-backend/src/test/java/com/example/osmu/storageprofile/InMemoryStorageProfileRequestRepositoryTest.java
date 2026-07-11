package com.example.osmu.storageprofile;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.storageprofile.repository.InMemoryStorageProfileRequestRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class InMemoryStorageProfileRequestRepositoryTest {

    @Test
    void pageFiltersStatusesAndUsesDescendingIdCursor() {
        InMemoryStorageProfileRequestRepository repository = new InMemoryStorageProfileRequestRepository();
        repository.save(request(1L, "alpha", "PENDING"));
        repository.save(request(2L, "beta", "APPLIED"));
        repository.save(request(3L, "gamma", "APPROVED"));
        repository.save(request(4L, "delta", "REJECTED"));
        repository.save(request(5L, "epsilon", "PENDING"));

        assertThat(repository.findPage(List.of("PENDING", "APPROVED"), null, 2))
                .extracting(StorageProfileRequestRecord::id)
                .containsExactly(5L, 3L);
        assertThat(repository.findPage(List.of(), 4L, 2))
                .extracting(StorageProfileRequestRecord::id)
                .containsExactly(3L, 2L);
    }

    @Test
    void bucketPagesFilterRequestsAndUseDescendingIdCursor() {
        InMemoryStorageProfileRequestRepository repository = new InMemoryStorageProfileRequestRepository();
        repository.save(request(1L, "alpha"));
        repository.save(request(3L, "alpha"));
        repository.save(request(2L, "beta"));
        repository.save(request(4L, "other"));

        assertThat(repository.findPageByBucketNames(List.of("alpha", "beta", "alpha"), 4L, 2))
                .extracting(StorageProfileRequestRecord::id)
                .containsExactly(3L, 2L);
        assertThat(repository.findPageByBucketName("alpha", 3L, 2))
                .extracting(StorageProfileRequestRecord::id)
                .containsExactly(1L);
        assertThat(repository.findPageByBucketNames(List.of(), null, 2)).isEmpty();
    }

    private StorageProfileRequestRecord request(long id, String bucketName) {
        return request(id, bucketName, "PENDING");
    }

    private StorageProfileRequestRecord request(long id, String bucketName, String status) {
        OffsetDateTime now = OffsetDateTime.now();
        return new StorageProfileRequestRecord(
                id,
                bucketName,
                "STANDARD",
                "PERFORMANCE",
                status,
                "reason",
                "developer",
                null,
                null,
                null,
                null,
                null,
                now,
                now
        );
    }
}