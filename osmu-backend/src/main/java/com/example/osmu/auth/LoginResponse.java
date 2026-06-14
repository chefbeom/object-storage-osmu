package com.example.osmu.auth;

import com.example.osmu.user.UserProfile;

public record LoginResponse(
        String accessToken,
        String refreshToken,
        UserProfile user
) {
}
