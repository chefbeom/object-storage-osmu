package com.example.osmu.auth;

import com.example.osmu.common.error.ApiException;

public interface LdapClient {

    LdapUserRecord searchUser(LdapSearchRequest request) throws ApiException;

    void bind(LdapBindRequest request) throws ApiException;
}
