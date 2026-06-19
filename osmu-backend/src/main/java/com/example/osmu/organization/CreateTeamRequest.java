package com.example.osmu.organization;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public record CreateTeamRequest(
        @NotNull Long organizationId,
        @NotBlank @Size(max = 100) String name,
        @Size(max = 500) String description,
        List<Long> memberIds
) {
}
