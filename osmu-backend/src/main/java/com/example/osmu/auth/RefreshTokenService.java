package com.example.osmu.auth;

import com.example.osmu.auth.repository.RefreshTokenRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserProfile;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.springframework.stereotype.Service;

@Service
public class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtTokenService jwtTokenService;

    public RefreshTokenService(RefreshTokenRepository refreshTokenRepository, JwtTokenService jwtTokenService) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.jwtTokenService = jwtTokenService;
    }

    public String issue(UserProfile user) {
        String refreshToken = jwtTokenService.createRefreshToken(user);
        JwtClaims claims = jwtTokenService.verifyRefreshToken(refreshToken);
        refreshTokenRepository.save(new RefreshTokenRecord(
                refreshTokenRepository.nextId(),
                user.id(),
                jwtTokenService.tokenHash(refreshToken),
                "ACTIVE",
                OffsetDateTime.ofInstant(Instant.ofEpochSecond(claims.expiresAt()), ZoneOffset.UTC),
                OffsetDateTime.now(),
                null
        ));
        return refreshToken;
    }

    public UserProfile verifyAndLoadUser(String refreshToken, UserProfile user) {
        JwtClaims claims = jwtTokenService.verifyRefreshToken(refreshToken);
        if (!Long.toString(user.id()).equals(claims.subject())) {
            throw invalidRefreshToken();
        }
        RefreshTokenRecord storedToken = refreshTokenRepository.findByTokenHash(jwtTokenService.tokenHash(refreshToken))
                .orElseThrow(this::invalidRefreshToken);
        if (!"ACTIVE".equals(storedToken.status())) {
            throw invalidRefreshToken();
        }
        if (storedToken.expiresAt().toEpochSecond() <= Instant.now().getEpochSecond()) {
            refreshTokenRepository.revokeByTokenHash(storedToken.tokenHash());
            throw invalidRefreshToken();
        }
        return user;
    }

    public void revoke(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            return;
        }
        refreshTokenRepository.revokeByTokenHash(jwtTokenService.tokenHash(refreshToken));
    }

    public void revokeAll(long userId) {
        refreshTokenRepository.revokeAllByUserId(userId);
    }

    private ApiException invalidRefreshToken() {
        return new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid refresh token.");
    }
}
