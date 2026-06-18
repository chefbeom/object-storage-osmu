package com.example.osmu.storageexpansion;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class StorageExpansionExecutionLogSanitizerTest {

    @Test
    void masksSecretsInCommandOutputAndNotes() {
        StorageExpansionExecutionLogSanitizer sanitizer = new StorageExpansionExecutionLogSanitizer(true, 16384);

        String output = sanitizer.output("""
                accessKey: minioadmin
                secret-key: super-secret
                OSMU_STORAGE_SECRET_KEY=qwer1234
                Authorization: Bearer abc.def.ghi
                https://user:pass@example.test/path?X-Amz-Signature=abcdef&ok=true
                """);

        assertTrue(output.contains("accessKey: [masked]"));
        assertTrue(output.contains("secret-key: [masked]"));
        assertTrue(output.contains("OSMU_STORAGE_SECRET_KEY=[masked]"));
        assertTrue(output.contains("Authorization: Bearer [masked]"));
        assertTrue(output.contains("https://user:[masked]@example.test/path?X-Amz-Signature=[masked]&ok=true"));
        assertFalse(output.contains("super-secret"));
        assertFalse(output.contains("qwer1234"));
        assertFalse(output.contains("abc.def.ghi"));

        String command = sanitizer.command("helm upgrade osmu --set secretKey=plain-secret");
        String notes = sanitizer.notes("token=operator-token");

        assertTrue(command.contains("secretKey=[masked]"));
        assertTrue(notes.contains("token=[masked]"));
    }

    @Test
    void truncatesLongOutputAfterMasking() {
        StorageExpansionExecutionLogSanitizer sanitizer = new StorageExpansionExecutionLogSanitizer(true, 1024);

        String output = sanitizer.output("password=abc\n" + "x".repeat(2000));

        assertTrue(output.length() <= 1024);
        assertTrue(output.contains("password=[masked]"));
        assertTrue(output.endsWith("[output truncated]"));
        assertFalse(output.contains("password=abc"));
    }
}
