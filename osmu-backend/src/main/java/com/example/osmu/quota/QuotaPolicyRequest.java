package com.example.osmu.quota;

import jakarta.validation.constraints.Positive;

public record QuotaPolicyRequest(
        @Positive Long quotaBytes,
        String reason
) {
}
