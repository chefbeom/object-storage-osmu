package com.example.osmu.auth.repository;

import com.example.osmu.auth.RefreshTokenRecord;
import java.util.Optional;

public interface RefreshTokenRepository {

    Optional<RefreshTokenRecord> findByTokenHash(String tokenHash);

    long nextId();

    RefreshTokenRecord save(RefreshTokenRecord token);

    void revokeByTokenHash(String tokenHash);

    void revokeAllByUserId(long userId);

    boolean isHealthy();
}
