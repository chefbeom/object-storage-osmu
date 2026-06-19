package com.example.osmu.organization;

import java.time.OffsetDateTime;

public record TeamRecord(
        long id,
        long organizationId,
        String name,
        String description,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
