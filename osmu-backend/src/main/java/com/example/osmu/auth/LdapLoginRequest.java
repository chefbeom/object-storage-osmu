package com.example.osmu.auth;

import jakarta.validation.constraints.NotBlank;

public record LdapLoginRequest(
        @NotBlank String loginId,
        @NotBlank String password
) {
}
