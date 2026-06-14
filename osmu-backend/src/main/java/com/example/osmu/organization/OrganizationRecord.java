package com.example.osmu.organization;

import java.time.OffsetDateTime;

public record OrganizationRecord(
        long id,
        String name,
        String description,
        long defaultQuotaBytes,
        OffsetDateTime createdAt
) {
}
