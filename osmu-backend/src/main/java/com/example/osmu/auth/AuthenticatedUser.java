package com.example.osmu.auth;

public record AuthenticatedUser(
        long id,
        String loginId,
        String role,
        Long organizationId
) {

    public boolean isAdmin() {
        return "ADMIN".equals(role);
    }

    public boolean isOrgAdmin() {
        return "ORG_ADMIN".equals(role);
    }

    public boolean isAuditor() {
        return "AUDITOR".equals(role);
    }
}
