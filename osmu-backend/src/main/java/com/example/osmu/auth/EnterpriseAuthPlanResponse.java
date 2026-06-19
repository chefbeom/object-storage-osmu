package com.example.osmu.auth;

import java.time.OffsetDateTime;
import java.util.List;

public record EnterpriseAuthPlanResponse(
        String status,
        String currentLoginMode,
        List<String> activeLoginModes,
        List<String> plannedExternalModes,
        boolean externalProviderConfigured,
        OidcProvider oidc,
        LdapProvider ldap,
        ClaimMapping claimMapping,
        List<RoleMapping> roleMappings,
        List<PlanGate> gates,
        List<String> nextImplementationSteps,
        OffsetDateTime generatedAt
) {
    public record OidcProvider(
            String status,
            String issuerUri,
            boolean clientIdConfigured
    ) {
    }

    public record LdapProvider(
            String status,
            String url,
            String baseDn
    ) {
    }

    public record ClaimMapping(
            String subjectClaim,
            String emailClaim,
            String nameClaim,
            String roleClaim,
            String organizationClaim,
            String teamClaim,
            List<String> allowedDomains,
            boolean jitProvisioningEnabled
    ) {
    }

    public record RoleMapping(
            String externalValue,
            String osmuRole,
            String scopeRule
    ) {
    }

    public record PlanGate(
            String key,
            String status,
            String detail
    ) {
    }
}
