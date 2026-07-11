package com.example.osmu.user;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.auth.PasswordService;
import com.example.osmu.user.repository.InMemoryUserRepository;
import java.util.List;
import org.junit.jupiter.api.Test;

class InMemoryUserRepositoryTest {

    private final InMemoryUserRepository repository = new InMemoryUserRepository(
            new PasswordService(),
            new BootstrapAdminProperties(false, false, "", "", "", "")
    );

    @Test
    void emailLookupIsCaseInsensitiveAndUpdatingEmailRemovesTheOldKey() {
        UserAccount original = user(10L, "mixed", "Mixed.Case@Example.com", 7L);
        repository.save(original);

        assertThat(repository.findByEmail("mixed.case@example.com")).contains(original);
        assertThat(repository.existsByEmail("MIXED.CASE@EXAMPLE.COM")).isTrue();

        UserAccount updated = user(10L, "mixed", "updated@example.com", 7L);
        repository.save(updated);

        assertThat(repository.findByEmail("mixed.case@example.com")).isEmpty();
        assertThat(repository.findByEmail("UPDATED@EXAMPLE.COM")).contains(updated);
    }

    @Test
    void organizationUserIdsAreFilteredAndOrderedWithoutReturningUserRows() {
        repository.save(user(12L, "third", "third@example.com", 7L));
        repository.save(user(10L, "first", "first@example.com", 7L));
        repository.save(user(11L, "other", "other@example.com", 8L));

        assertThat(repository.findIdsByOrganizationId(7L)).isEqualTo(List.of(10L, 12L));
    }

    @Test
    void userRowsCanBeLoadedByDistinctIdsInStableOrder() {
        UserAccount user12 = user(12L, "third", "third@example.com", 7L);
        UserAccount user10 = user(10L, "first", "first@example.com", 7L);
        repository.save(user12);
        repository.save(user10);

        assertThat(repository.findByIds(java.util.Arrays.asList(12L, null, 10L, 12L, 999L)))
                .containsExactly(user10, user12);
        assertThat(repository.findByIds(List.of())).isEmpty();
        assertThat(repository.findByIds(null)).isEmpty();
    }

    private UserAccount user(long id, String loginId, String email, Long organizationId) {
        return new UserAccount(id, loginId, email, loginId, "hash", "USER", "ACTIVE", organizationId);
    }
}