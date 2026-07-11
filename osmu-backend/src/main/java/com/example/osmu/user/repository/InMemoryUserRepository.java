package com.example.osmu.user.repository;

import com.example.osmu.auth.PasswordService;
import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.UserAccount;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryUserRepository implements UserRepository {

    private final ConcurrentMap<Long, UserAccount> usersById = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, UserAccount> usersByLoginId = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, UserAccount> usersByEmail = new ConcurrentHashMap<>();
    private final AtomicLong idSequence = new AtomicLong(2);

    public InMemoryUserRepository(
            PasswordService passwordService,
            BootstrapAdminProperties bootstrapAdminProperties
    ) {
        bootstrapAdminProperties.createAdmin(1L, passwordService).ifPresent(this::save);
    }


    @Override
    public List<UserAccount> findByIds(List<Long> userIds) {
        java.util.Set<Long> ids = new java.util.HashSet<>(userIds == null ? List.of() : userIds);
        ids.remove(null);
        if (ids.isEmpty()) {
            return List.of();
        }
        return usersById.values().stream()
                .filter(user -> ids.contains(user.id()))
                .sorted(Comparator.comparingLong(UserAccount::id))
                .toList();
    }

    @Override
    public List<UserAccount> findPage(
            Long organizationId,
            String keyword,
            String status,
            Long cursorId,
            int limit
    ) {
        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase(Locale.ROOT);
        String normalizedStatus = status == null ? "" : status.trim();
        return usersById.values().stream()
                .filter(user -> organizationId == null || organizationId.equals(user.organizationId()))
                .filter(user -> normalizedKeyword.isBlank()
                        || containsIgnoreCase(user.loginId(), normalizedKeyword)
                        || containsIgnoreCase(user.email(), normalizedKeyword)
                        || containsIgnoreCase(user.name(), normalizedKeyword))
                .filter(user -> normalizedStatus.isBlank() || user.status().equalsIgnoreCase(normalizedStatus))
                .filter(user -> cursorId == null || user.id() < cursorId)
                .sorted(Comparator.comparingLong(UserAccount::id).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public List<Long> findIdsByOrganizationId(long organizationId) {
        return usersById.values().stream()
                .filter(user -> user.organizationId() != null && user.organizationId() == organizationId)
                .map(UserAccount::id)
                .sorted()
                .toList();
    }

    private boolean containsIgnoreCase(String value, String normalizedKeyword) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(normalizedKeyword);
    }

    @Override
    public Optional<UserAccount> findById(long id) {
        return Optional.ofNullable(usersById.get(id));
    }

    @Override
    public Optional<UserAccount> findByLoginId(String loginId) {
        return Optional.ofNullable(usersByLoginId.get(loginId));
    }

    @Override
    public Optional<UserAccount> findByEmail(String email) {
        return Optional.ofNullable(usersByEmail.get(normalizeEmail(email)));
    }

    @Override
    public boolean existsByLoginId(String loginId) {
        return usersByLoginId.containsKey(loginId);
    }

    @Override
    public boolean existsByEmail(String email) {
        return usersByEmail.containsKey(normalizeEmail(email));
    }

    @Override
    public boolean existsByOrganizationId(long organizationId) {
        return usersById.values().stream()
                .anyMatch(user -> user.organizationId() != null && user.organizationId() == organizationId);
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public UserAccount save(UserAccount user) {
        UserAccount previous = usersById.put(user.id(), user);
        if (previous != null) {
            usersByLoginId.remove(previous.loginId());
            usersByEmail.remove(normalizeEmail(previous.email()));
        }
        usersByLoginId.put(user.loginId(), user);
        usersByEmail.put(normalizeEmail(user.email()), user);
        return user;
    }

    private String normalizeEmail(String email) {
        return email.toLowerCase(Locale.ROOT);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
