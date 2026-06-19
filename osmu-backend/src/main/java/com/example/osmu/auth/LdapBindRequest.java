package com.example.osmu.auth;

public record LdapBindRequest(
        String url,
        String userDn,
        String password,
        int connectTimeoutMs,
        int readTimeoutMs
) {
}
