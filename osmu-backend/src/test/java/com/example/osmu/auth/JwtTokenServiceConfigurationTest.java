package com.example.osmu.auth;

import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class JwtTokenServiceConfigurationTest {

    private static final String SECRET = "unit-test-jwt-secret-change-me-32-chars";

    @Test
    void rejectsNonPositiveTokenTtl() {
        assertThrows(IllegalStateException.class, () -> new JwtTokenService(SECRET, "osmu-test", 0, 60));
        assertThrows(IllegalStateException.class, () -> new JwtTokenService(SECRET, "osmu-test", 60, -1));
    }
}
