package com.example.osmu.bucket;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.bucket.repository.InMemoryBucketPermissionRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class InMemoryBucketPermissionRepositoryTest {

    @Test
    void findsDistinctBucketIdsAcrossUserOrganizationAndTeamSubjects() {
        InMemoryBucketPermissionRepository repository = new InMemoryBucketPermissionRepository();
        repository.save(permission(1L, 10L, "USER", 7L, "READ"));
        repository.save(permission(2L, 10L, "USER", 7L, "WRITE"));
        repository.save(permission(3L, 11L, "ORGANIZATION", 9L, "READ"));
        repository.save(permission(4L, 12L, "TEAM", 31L, "READ"));
        repository.save(permission(5L, 13L, "TEAM", 99L, "READ"));
        repository.save(permission(6L, 14L, "USER", 8L, "READ"));

        assertThat(repository.findBucketIdsBySubjects(7L, 9L, List.of(31L, 32L)))
                .containsExactly(10L, 11L, 12L);
        assertThat(repository.findBucketIdsBySubjects(7L, null, List.of()))
                .containsExactly(10L);
    }

    private BucketPermissionRecord permission(
            long id,
            long bucketId,
            String subjectType,
            long subjectId,
            String permission
    ) {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        return new BucketPermissionRecord(id, bucketId, subjectType, subjectId, permission, now, now);
    }
}
