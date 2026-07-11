package com.example.osmu.organization;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.organization.repository.InMemoryTeamRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class InMemoryTeamRepositoryTest {

    @Test
    void pagesTeamsByOrganizationAndLoadsMembersInBulk() {
        InMemoryTeamRepository repository = new InMemoryTeamRepository();
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        repository.save(new TeamRecord(1L, 10L, "Alpha", "", now, now));
        repository.save(new TeamRecord(2L, 10L, "Beta", "", now, now));
        repository.save(new TeamRecord(3L, 20L, "Gamma", "", now, now));
        repository.replaceMembers(1L, List.of(100L, 101L));
        repository.replaceMembers(2L, List.of(102L));

        assertThat(repository.findPage(10L, null, 2))
                .extracting(TeamRecord::id)
                .containsExactly(1L, 2L);
        assertThat(repository.findPage(10L, 1L, 2))
                .extracting(TeamRecord::id)
                .containsExactly(2L);
        assertThat(repository.findMemberIdsByTeamIds(List.of(2L, 1L, 99L)))
                .containsEntry(1L, List.of(100L, 101L))
                .containsEntry(2L, List.of(102L))
                .doesNotContainKey(99L);
    }
}