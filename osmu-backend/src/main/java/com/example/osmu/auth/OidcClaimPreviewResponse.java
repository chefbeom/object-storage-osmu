package com.example.osmu.auth;

import java.time.OffsetDateTime;
import java.util.List;

public record OidcClaimPreviewResponse(
        String status,
        String subject,
        String email,
        String name,
        List<String> roleClaimValues,
        List<String> mappedRoles,
        String primaryRole,
        String organizationClaimValue,
        List<String> teamClaimValues,
        boolean allowedDomainMatched,
        ExistingUser existingUser,
        boolean jitProvisioningRequired,
        boolean adminApprovalRequired,
        List<String> warnings,
        OffsetDateTime generatedAt,
        long auditLogId
) {

    public OidcClaimPreviewResponse withAuditLogId(long auditLogId) {
        return new OidcClaimPreviewResponse(
                status,
                subject,
                email,
                name,
                roleClaimValues,
                mappedRoles,
                primaryRole,
                organizationClaimValue,
                teamClaimValues,
                allowedDomainMatched,
                existingUser,
                jitProvisioningRequired,
                adminApprovalRequired,
                warnings,
                generatedAt,
                auditLogId
        );
    }

    public record ExistingUser(
            long id,
            String loginId,
            String role,
            String status
    ) {
    }
}
