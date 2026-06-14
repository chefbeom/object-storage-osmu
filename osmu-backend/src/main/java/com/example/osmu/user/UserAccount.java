package com.example.osmu.user;

public record UserAccount(
        long id,
        String loginId,
        String email,
        String name,
        String passwordHash,
        String role,
        String status,
        Long organizationId
) {

    public UserProfile toProfile() {
        return new UserProfile(id, loginId, email, name, role, status, organizationId);
    }
}
