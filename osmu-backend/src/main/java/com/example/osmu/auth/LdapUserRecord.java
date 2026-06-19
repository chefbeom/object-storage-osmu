package com.example.osmu.auth;

public record LdapUserRecord(
        String dn,
        String email,
        String name
) {
}
