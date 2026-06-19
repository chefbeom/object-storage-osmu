package com.example.osmu.auth;

import com.example.osmu.user.UserProfile;

public record OidcJitProvisionResponse(
        String status,
        UserProfile user,
        OidcClaimPreviewResponse preview,
        String approvedRole,
        Long organizationId,
        boolean privilegedRoleApproved,
        long auditLogId
) {

    public OidcJitProvisionResponse withAuditLogId(long auditLogId) {
        return new OidcJitProvisionResponse(
                status,
                user,
                preview,
                approvedRole,
                organizationId,
                privilegedRoleApproved,
                auditLogId
        );
    }
}
