package com.example.osmu.user.repository;

import com.example.osmu.user.UserAccount;
import java.util.List;
import java.util.Optional;

public interface UserRepository {

    List<UserAccount> findAll();

    Optional<UserAccount> findById(long id);

    Optional<UserAccount> findByLoginId(String loginId);

    boolean existsByLoginId(String loginId);

    boolean existsByEmail(String email);

    long nextId();

    UserAccount save(UserAccount user);

    boolean isHealthy();
}
