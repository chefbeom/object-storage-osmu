package com.example.osmu.accesskey;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class AccessKeySecretCipherTest {

    @Test
    void rejectsMissingOrShortEncryptionKey() {
        assertThrows(IllegalStateException.class, () -> new AccessKeySecretCipher(""));
        assertThrows(IllegalStateException.class, () -> new AccessKeySecretCipher("short-key"));
    }

    @Test
    void encryptsAndDecryptsWithConfiguredKey() {
        AccessKeySecretCipher cipher = new AccessKeySecretCipher("unit-test-access-key-encryption-key-32+");

        assertEquals("secret-value", cipher.decrypt(cipher.encrypt("secret-value")));
    }
}
