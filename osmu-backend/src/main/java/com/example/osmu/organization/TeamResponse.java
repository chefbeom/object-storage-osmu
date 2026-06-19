package com.example.osmu.organization;

import java.time.OffsetDateTime;
import java.util.List;

public record TeamResponse(
        long id,
        long organizationId,
        String name,
        String description,
        List<Long> memberIds,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {

    public static TeamResponse of(TeamRecord team, List<Long> memberIds) {
        return new TeamResponse(
                team.id(),
                team.organizationId(),
                team.name(),
                team.description(),
                memberIds,
                team.createdAt(),
                team.updatedAt()
        );
    }
}
