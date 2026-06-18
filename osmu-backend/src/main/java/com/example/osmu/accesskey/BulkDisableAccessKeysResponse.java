package com.example.osmu.accesskey;

import java.util.List;

public record BulkDisableAccessKeysResponse(
        int requestedCount,
        int disabledCount,
        int skippedCount,
        List<Long> disabledKeyIds,
        List<Long> skippedKeyIds
) {
}
