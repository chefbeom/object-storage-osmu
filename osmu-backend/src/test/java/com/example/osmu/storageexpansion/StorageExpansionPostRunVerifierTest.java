package com.example.osmu.storageexpansion;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.example.osmu.storage.memory.InMemoryObjectStorageAdapter;
import org.junit.jupiter.api.Test;

class StorageExpansionPostRunVerifierTest {

    @Test
    void verifiesStorageHealthAndS3PutGetList() {
        StorageExpansionPostRunVerifier verifier = new StorageExpansionPostRunVerifier(
                new InMemoryObjectStorageAdapter(),
                true,
                "osmu-expansion-test"
        );

        StorageExpansionPostRunVerification verification = verifier.verify("APPLY", 7L, true);

        assertTrue(verification.success());
        assertTrue(verification.summary().contains("databaseHealth: UP"));
        assertTrue(verification.summary().contains("storageHealth: UP"));
        assertTrue(verification.summary().contains("s3Put: PASS"));
        assertTrue(verification.summary().contains("s3Get: PASS"));
        assertTrue(verification.summary().contains("s3List: PASS"));
        assertTrue(verification.notes().contains("postRun=SUCCESS"));
    }

    @Test
    void failsGateWhenDatabaseHealthIsDown() {
        StorageExpansionPostRunVerifier verifier = new StorageExpansionPostRunVerifier(
                new InMemoryObjectStorageAdapter(),
                true,
                "osmu-expansion-test"
        );

        StorageExpansionPostRunVerification verification = verifier.verify("ROLLBACK", 8L, false);

        assertFalse(verification.success());
        assertTrue(verification.summary().contains("databaseHealth: DOWN"));
        assertTrue(verification.notes().contains("postRun=FAILED"));
    }

    @Test
    void acceptsLongBucketPrefixByTrimmingToS3CompatibleName() {
        StorageExpansionPostRunVerifier verifier = new StorageExpansionPostRunVerifier(
                new InMemoryObjectStorageAdapter(),
                true,
                "osmu-expansion-test-prefix-that-is-intentionally-longer-than-s3-bucket-limit"
        );

        StorageExpansionPostRunVerification verification = verifier.verify("APPLY", 9L, true);

        assertTrue(verification.success());
        assertTrue(verification.notes().contains("postRun=SUCCESS"));
    }
}
