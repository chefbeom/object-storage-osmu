package com.example.osmu.auth.repository;

import com.example.osmu.auth.RefreshTokenRecord;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryRefreshTokenRepository implements RefreshTokenRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<String, RefreshTokenRecord> tokens = new ConcurrentHashMap<>();

    @Override
    public Optional<RefreshTokenRecord> findByTokenHash(String tokenHash) {
        return Optional.ofNullable(tokens.get(tokenHash));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public RefreshTokenRecord save(RefreshTokenRecord token) {
        tokens.put(token.tokenHash(), token);
        return token;
    }

    @Override
    public void revokeByTokenHash(String tokenHash) {
        RefreshTokenRecord token = tokens.get(tokenHash);
        if (token == null || "REVOKED".equals(token.status())) {
            return;
        }
        tokens.put(tokenHash, revoke(token));
    }

    @Override
    public void revokeAllByUserId(long userId) {
        tokens.replaceAll((tokenHash, token) -> token.userId() == userId ? revoke(token) : token);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private RefreshTokenRecord revoke(RefreshTokenRecord token) {
        return new RefreshTokenRecord(
                token.id(),
                token.userId(),
                token.tokenHash(),
                "REVOKED",
                token.expiresAt(),
                token.createdAt(),
                OffsetDateTime.now()
        );
    }
}
