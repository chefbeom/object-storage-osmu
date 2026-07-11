package com.example.osmu.storageexpansion;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.storageexpansion.repository.InMemoryStorageExpansionExecutionRepository;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class InMemoryStorageExpansionExecutionRepositoryTest {

    private final InMemoryStorageExpansionExecutionRepository repository =
            new InMemoryStorageExpansionExecutionRepository();

    @Test
    void requestPageUsesDescendingIdCursorAndLimit() {
        repository.save(execution(1L, 10L));
        repository.save(execution(2L, 20L));
        repository.save(execution(3L, 10L));
        repository.save(execution(4L, 10L));
        repository.save(execution(5L, 10L));

        assertThat(repository.findPageByRequestId(10L, null, 2))
                .extracting(StorageExpansionExecutionRecord::id)
                .containsExactly(5L, 4L);
        assertThat(repository.findPageByRequestId(10L, 4L, 2))
                .extracting(StorageExpansionExecutionRecord::id)
                .containsExactly(3L, 1L);
    }

    private StorageExpansionExecutionRecord execution(long id, long requestId) {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        return new StorageExpansionExecutionRecord(
                id, requestId, "HELM_DIFF", "SUCCESS", "helm diff", "clean", null,
                "sha256", 0, false, "notes", "admin", now
        );
    }
}
