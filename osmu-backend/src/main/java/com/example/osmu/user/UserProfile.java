package com.example.osmu.user;

public record UserProfile(
        long id,
        String loginId,
        String email,
        String name,
        String role,
        String status,
        Long organizationId
) {

    public static UserProfile admin() {
        return new UserProfile(1L, "admin", "admin@example.com", "Admin", "ADMIN", "ACTIVE", null);
    }
}
