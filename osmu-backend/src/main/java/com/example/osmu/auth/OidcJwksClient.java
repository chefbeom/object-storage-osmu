package com.example.osmu.auth;

import java.util.Map;

public interface OidcJwksClient {

    Map<String, Object> getJwks(String jwksUri);
}
