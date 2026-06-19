package com.example.osmu.auth;

import jakarta.validation.constraints.NotNull;
import java.util.Map;

public record OidcClaimPreviewRequest(
        @NotNull Map<String, Object> claims
) {
}
