package com.example.osmu.user.repository;

import com.example.osmu.auth.PasswordService;
import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.UserAccount;
import java.util.Comparator;
import java.util.List;
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
    public List<UserAccount> findAll() {
        return usersById.values().stream()
                .sorted(Comparator.comparing(UserAccount::id))
                .toList();
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
    public boolean existsByLoginId(String loginId) {
        return usersByLoginId.containsKey(loginId);
    }

    @Override
    public boolean existsByEmail(String email) {
        return usersByEmail.containsKey(email);
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
            usersByEmail.remove(previous.email());
        }
        usersByLoginId.put(user.loginId(), user);
        usersByEmail.put(user.email(), user);
        return user;
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
