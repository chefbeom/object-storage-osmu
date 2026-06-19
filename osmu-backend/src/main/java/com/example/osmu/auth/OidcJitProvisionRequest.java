package com.example.osmu.auth;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Map;

public record OidcJitProvisionRequest(
        @NotNull Map<String, Object> claims,
        @Pattern(regexp = "ADMIN|ORG_ADMIN|AUDITOR|USER") String approvedRole,
        Long organizationId,
        Boolean approvePrivilegedRole,
        @Size(max = 300) String reason
) {
}
