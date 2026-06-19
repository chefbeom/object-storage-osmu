package com.example.osmu.auth;

public record LdapSearchRequest(
        String url,
        String bindDn,
        String bindPassword,
        String baseDn,
        String userSearchFilter,
        String loginId,
        String emailAttribute,
        String displayNameAttribute,
        int connectTimeoutMs,
        int readTimeoutMs
) {
}
