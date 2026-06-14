package com.example.osmu.auth;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class PasswordServiceTest {

    private final PasswordService passwordService = new PasswordService();

    @Test
    void hashUsesSaltAndMatchesRawPassword() {
        String firstHash = passwordService.hash("password");
        String secondHash = passwordService.hash("password");

        assertNotEquals(firstHash, secondHash);
        assertTrue(passwordService.matches("password", firstHash));
        assertTrue(passwordService.matches("password", secondHash));
        assertFalse(passwordService.matches("wrong", firstHash));
    }
}
