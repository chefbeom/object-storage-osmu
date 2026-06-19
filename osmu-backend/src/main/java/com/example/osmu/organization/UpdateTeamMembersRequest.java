package com.example.osmu.organization;

import jakarta.validation.constraints.NotNull;
import java.util.List;

public record UpdateTeamMembersRequest(
        @NotNull List<Long> memberIds
) {
}
