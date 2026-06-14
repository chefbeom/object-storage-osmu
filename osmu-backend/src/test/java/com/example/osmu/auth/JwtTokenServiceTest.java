package com.example.osmu.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserProfile;
import org.junit.jupiter.api.Test;

class JwtTokenServiceTest {

    private final JwtTokenService jwtTokenService = new JwtTokenService(
            "unit-test-jwt-secret-change-me-32-chars",
            "osmu-test",
            3600,
            604800
    );

    @Test
    void verifyAccessTokenReturnsClaims() {
        String token = jwtTokenService.createAccessToken(UserProfile.admin());

        JwtClaims claims = jwtTokenService.verifyAccessToken(token);

        assertEquals("1", claims.subject());
        assertEquals("admin", claims.loginId());
        assertEquals("ADMIN", claims.role());
        assertEquals("access", claims.tokenType());
    }

    @Test
    void verifyAccessTokenRejectsTamperedToken() {
        String token = jwtTokenService.createAccessToken(UserProfile.admin());
        char replacement = token.charAt(token.length() - 1) == 'x' ? 'y' : 'x';
        String tamperedToken = token.substring(0, token.length() - 1) + replacement;

        assertThrows(ApiException.class, () -> jwtTokenService.verifyAccessToken(tamperedToken));
    }

    @Test
    void verifyAccessTokenRejectsRefreshToken() {
        String refreshToken = jwtTokenService.createRefreshToken(UserProfile.admin());

        assertThrows(ApiException.class, () -> jwtTokenService.verifyAccessToken(refreshToken));
    }

    @Test
    void verifyRefreshTokenReturnsClaims() {
        String refreshToken = jwtTokenService.createRefreshToken(UserProfile.admin());

        JwtClaims claims = jwtTokenService.verifyRefreshToken(refreshToken);

        assertEquals("1", claims.subject());
        assertEquals("admin", claims.loginId());
        assertEquals("ADMIN", claims.role());
        assertEquals("refresh", claims.tokenType());
    }

    @Test
    void tokenHashIsStableAndDoesNotExposeToken() {
        String refreshToken = jwtTokenService.createRefreshToken(UserProfile.admin());

        String tokenHash = jwtTokenService.tokenHash(refreshToken);

        assertEquals(tokenHash, jwtTokenService.tokenHash(refreshToken));
        assertEquals(64, tokenHash.length());
    }
}
