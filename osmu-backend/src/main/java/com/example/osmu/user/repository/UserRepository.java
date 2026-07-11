package com.example.osmu.user.repository;

import com.example.osmu.user.UserAccount;
import java.util.List;
import java.util.Optional;

public interface UserRepository {


    List<UserAccount> findByIds(List<Long> userIds);

    List<UserAccount> findPage(Long organizationId, String keyword, String status, Long cursorId, int limit);

    List<Long> findIdsByOrganizationId(long organizationId);

    Optional<UserAccount> findById(long id);

    Optional<UserAccount> findByLoginId(String loginId);

    Optional<UserAccount> findByEmail(String email);

    boolean existsByLoginId(String loginId);

    boolean existsByEmail(String email);

    boolean existsByOrganizationId(long organizationId);

    long nextId();

    UserAccount save(UserAccount user);

    boolean isHealthy();
}
