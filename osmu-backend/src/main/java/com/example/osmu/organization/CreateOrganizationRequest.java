package com.example.osmu.organization;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public record CreateOrganizationRequest(
        @NotBlank @Size(max = 100) String name,
        @Size(max = 500) String description,
        @PositiveOrZero Long defaultQuotaBytes
) {
}
