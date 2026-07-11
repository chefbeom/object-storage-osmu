package com.example.osmu.storageexpansion;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.storageexpansion.repository.InMemoryStorageExpansionRequestRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class InMemoryStorageExpansionRequestRepositoryTest {

    private final InMemoryStorageExpansionRequestRepository repository =
            new InMemoryStorageExpansionRequestRepository();

    @Test
    void pageFiltersStatusesAndUsesDescendingIdCursor() {
        repository.save(request(1L, "PLANNED"));
        repository.save(request(2L, "APPLIED"));
        repository.save(request(3L, "APPROVED"));
        repository.save(request(4L, "REJECTED"));
        repository.save(request(5L, "PLANNED"));

        assertThat(repository.findPage(List.of("PLANNED", "APPROVED"), null, 2))
                .extracting(StorageExpansionRequestRecord::id)
                .containsExactly(5L, 3L);
        assertThat(repository.findPage(List.of(), 4L, 2))
                .extracting(StorageExpansionRequestRecord::id)
                .containsExactly(3L, 2L);
    }

    private StorageExpansionRequestRecord request(long id, String status) {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        return new StorageExpansionRequestRecord(
                id, 100L, 4, 1, 50L, 200L, 100L, status, "reason", "admin",
                null, null, null, now, now
        );
    }
}
