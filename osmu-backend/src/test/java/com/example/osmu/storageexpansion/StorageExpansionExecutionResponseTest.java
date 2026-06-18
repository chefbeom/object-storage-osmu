package com.example.osmu.storageexpansion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class StorageExpansionExecutionResponseTest {

    @Test
    void extractsGitOpsFailureReasonFromNotes() {
        StorageExpansionExecutionResponse response = StorageExpansionExecutionResponse.of(record(
                "gitOpsPrRunner=FAILED, exitCode=1, timedOut=false, externalUrl=-, failureReason=BRANCH_PROTECTION"
        ));

        assertEquals("BRANCH_PROTECTION", response.failureReason());
    }

    @Test
    void returnsNullWhenFailureReasonIsMissingOrDisabled() {
        assertNull(StorageExpansionExecutionResponse.of(record("operator checked diff")).failureReason());
        assertNull(StorageExpansionExecutionResponse.of(record("gitOpsPrRunner=SKIPPED, failureReason=-")).failureReason());
    }

    private StorageExpansionExecutionRecord record(String notes) {
        return new StorageExpansionExecutionRecord(
                1L,
                1L,
                "GITOPS_PR",
                "FAILED",
                "git push -u origin storage-expansion/pool-1",
                "remote: GH006: Protected branch update failed",
                null,
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                1,
                false,
                notes,
                "admin",
                OffsetDateTime.parse("2026-06-15T10:00:00+09:00")
        );
    }
}
